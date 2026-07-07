"""ApnsFcmProvider (item 11d) — FCM v1 delivery + service-account OAuth.

A locally generated RSA key plays the service account; httpx.MockTransport
plays both Google's token endpoint and the FCM send endpoint, so the JWT
grant, token caching, message shape, and the never-raise contract are all
exercised for real.
"""
from __future__ import annotations

import base64
import json
from urllib.parse import parse_qs

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from app.services.providers.push.apns_fcm import ApnsFcmProvider
from app.services.push_service import notify_user, register_device

_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_PEM = _KEY.private_bytes(
    serialization.Encoding.PEM,
    serialization.PrivateFormat.PKCS8,
    serialization.NoEncryption(),
).decode()

_TOKEN_URI = "https://oauth2.googleapis.com/token"
_CREDS = json.dumps(
    {
        "type": "service_account",
        "project_id": "drape-test",
        "private_key": _PEM,
        "client_email": "push@drape-test.iam.gserviceaccount.com",
        "token_uri": _TOKEN_URI,
    }
)
_SEND_URL = "https://fcm.googleapis.com/v1/projects/drape-test/messages:send"


class _FakeGoogle:
    """Routes token-exchange and FCM-send requests; records everything."""

    def __init__(self, *, send_status: int = 200, token_status: int = 200) -> None:
        self.token_requests: list[httpx.Request] = []
        self.send_requests: list[httpx.Request] = []
        self.send_status = send_status
        self.token_status = token_status

    def __call__(self, request: httpx.Request) -> httpx.Response:
        if str(request.url) == _TOKEN_URI:
            self.token_requests.append(request)
            return httpx.Response(
                self.token_status, json={"access_token": "at_test", "expires_in": 3600}
            )
        self.send_requests.append(request)
        if self.send_status >= 400:
            return httpx.Response(self.send_status, json={"error": {"status": "UNREGISTERED"}})
        return httpx.Response(200, json={"name": "projects/drape-test/messages/m1"})


@pytest.fixture
def fake_google(monkeypatch) -> _FakeGoogle:
    fake = _FakeGoogle()
    real_client = httpx.Client
    monkeypatch.setattr(
        httpx,
        "Client",
        lambda **kwargs: real_client(transport=httpx.MockTransport(fake)),
    )
    return fake


def _send(provider: ApnsFcmProvider, **overrides) -> None:
    kwargs = dict(
        device_token="fcm-device-token-1",
        platform="android",
        title="Hello",
        body="World",
        data={"route": "today"},
    )
    kwargs.update(overrides)
    provider.send(**kwargs)


# ---------------------------------------------------------------------------
# Delivery
# ---------------------------------------------------------------------------


def test_send_posts_fcm_v1_message(fake_google):
    provider = ApnsFcmProvider(fcm_credentials_json=_CREDS)
    _send(provider)

    assert len(fake_google.send_requests) == 1
    request = fake_google.send_requests[0]
    assert str(request.url) == _SEND_URL
    assert request.headers["authorization"] == "Bearer at_test"
    message = json.loads(request.content)["message"]
    assert message["token"] == "fcm-device-token-1"
    assert message["notification"] == {"title": "Hello", "body": "World"}
    assert message["data"] == {"route": "today"}


def test_oauth_assertion_is_a_valid_service_account_grant(fake_google):
    provider = ApnsFcmProvider(fcm_credentials_json=_CREDS)
    _send(provider)

    token_request = fake_google.token_requests[0]
    form = {k: v[0] for k, v in parse_qs(token_request.content.decode()).items()}
    assert form["grant_type"] == "urn:ietf:params:oauth:grant-type:jwt-bearer"
    claims = jwt.decode(
        form["assertion"],
        _KEY.public_key(),
        algorithms=["RS256"],
        audience=_TOKEN_URI,
    )
    assert claims["iss"] == "push@drape-test.iam.gserviceaccount.com"
    assert claims["scope"] == "https://www.googleapis.com/auth/firebase.messaging"


def test_access_token_cached_across_sends(fake_google):
    provider = ApnsFcmProvider(fcm_credentials_json=_CREDS)
    _send(provider)
    _send(provider, device_token="fcm-device-token-2")
    assert len(fake_google.token_requests) == 1
    assert len(fake_google.send_requests) == 2


def test_expired_access_token_refreshed(fake_google):
    provider = ApnsFcmProvider(fcm_credentials_json=_CREDS)
    _send(provider)
    provider._token_expires_at = 0.0  # force expiry
    _send(provider)
    assert len(fake_google.token_requests) == 2


# ---------------------------------------------------------------------------
# The never-raise contract
# ---------------------------------------------------------------------------


def test_unregistered_token_swallowed(monkeypatch):
    fake = _FakeGoogle(send_status=404)
    real_client = httpx.Client
    monkeypatch.setattr(
        httpx, "Client", lambda **kw: real_client(transport=httpx.MockTransport(fake))
    )
    ApnsFcmProvider(fcm_credentials_json=_CREDS).send(
        device_token="dead", platform="ios", title="t", body="b"
    )  # no raise


def test_fcm_rejection_swallowed(monkeypatch):
    fake = _FakeGoogle(send_status=500)
    real_client = httpx.Client
    monkeypatch.setattr(
        httpx, "Client", lambda **kw: real_client(transport=httpx.MockTransport(fake))
    )
    _send(ApnsFcmProvider(fcm_credentials_json=_CREDS))  # no raise


def test_token_endpoint_failure_swallowed(monkeypatch):
    fake = _FakeGoogle(token_status=500)
    real_client = httpx.Client
    monkeypatch.setattr(
        httpx, "Client", lambda **kw: real_client(transport=httpx.MockTransport(fake))
    )
    _send(ApnsFcmProvider(fcm_credentials_json=_CREDS))  # no raise
    assert fake.send_requests == []  # never got past auth


def test_network_failure_swallowed(monkeypatch):
    def boom(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("down")

    real_client = httpx.Client
    monkeypatch.setattr(
        httpx, "Client", lambda **kw: real_client(transport=httpx.MockTransport(boom))
    )
    _send(ApnsFcmProvider(fcm_credentials_json=_CREDS))  # no raise


# ---------------------------------------------------------------------------
# Credential parsing (construction fails fast, per config convention)
# ---------------------------------------------------------------------------


def test_base64_encoded_credentials_accepted():
    encoded = base64.b64encode(_CREDS.encode()).decode()
    provider = ApnsFcmProvider(fcm_credentials_json=encoded)
    assert provider._project_id == "drape-test"


def test_garbage_credentials_rejected_at_construction():
    with pytest.raises(ValueError, match="neither JSON nor base64"):
        ApnsFcmProvider(fcm_credentials_json="not-json-not-base64!!!")


def test_missing_fields_rejected_at_construction():
    incomplete = json.dumps({"project_id": "p"})
    with pytest.raises(ValueError, match="client_email"):
        ApnsFcmProvider(fcm_credentials_json=incomplete)


# ---------------------------------------------------------------------------
# Disabled-push fan-out (DISABLED_FEATURES=push wires providers.push = None)
# ---------------------------------------------------------------------------


def test_notify_user_with_disabled_push_is_a_noop(db, make_user):
    user = make_user(email="pushless@example.com")
    register_device(db, user=user, platform="ios", token="tok-1")
    sent = notify_user(db, push=None, user_id=user.id, title="t", body="b")
    assert sent == 0  # skipped, logged, no crash
