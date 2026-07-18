"""StripeProvider (item 11c) — REST calls, customer mapping, webhook signatures.

`_request` is replaced with a scripted recorder for the flow tests (what gets
sent to which endpoint); the HTTP/error-mapping layer of `_request` itself is
exercised for real through httpx.MockTransport.
"""
from __future__ import annotations

import hashlib
import hmac
import json
import time
import uuid

import httpx
import pytest

from app.services.providers.payment.base import PaymentProviderError
from app.services.providers.payment.stripe import (
    StripeProvider,
    verify_webhook_signature,
)

_USER_ID = uuid.UUID("00000000-0000-0000-0000-00000000abcd")
_PRICES = {"pro_monthly": "price_month", "pro_yearly": "price_year"}


def _provider() -> StripeProvider:
    return StripeProvider(
        api_key="sk_test_x",
        price_ids=_PRICES,
        portal_return_url="zoura://billing",
        environment="tbd",
    )


class _ScriptedRequests:
    """Stands in for StripeProvider._request; returns canned responses in order."""

    def __init__(self, responses: list[dict]) -> None:
        self.calls: list[tuple[str, str, dict]] = []
        self._responses = list(responses)

    def __call__(self, method: str, path: str, **kwargs) -> dict:
        self.calls.append((method, path, kwargs))
        return self._responses.pop(0)


_SEARCH_HIT = {"data": [{"id": "cus_existing"}]}
_SEARCH_MISS = {"data": []}


# ---------------------------------------------------------------------------
# Subscriptions
# ---------------------------------------------------------------------------


def test_create_subscription_charges_configured_price():
    provider = _provider()
    stub = _ScriptedRequests(
        [
            _SEARCH_HIT,
            {
                "id": "sub_123",
                "latest_invoice": {"number": "INV-42", "amount_paid": 999, "currency": "cad"},
            },
        ]
    )
    provider._request = stub

    result = provider.create_subscription(
        user_id=_USER_ID, plan="pro_monthly", amount_cents=999, currency="CAD"
    )

    assert result.provider_subscription_id == "sub_123"
    assert result.invoice_number == "INV-42"
    assert result.amount_cents == 999
    assert result.currency == "CAD"

    method, path, kwargs = stub.calls[1]
    assert (method, path) == ("POST", "/subscriptions")
    assert kwargs["data"]["customer"] == "cus_existing"
    assert kwargs["data"]["items[0][price]"] == "price_month"
    assert kwargs["data"]["payment_behavior"] == "error_if_incomplete"


def test_create_subscription_unconfigured_plan_rejected():
    provider = _provider()
    stub = _ScriptedRequests([])
    provider._request = stub
    with pytest.raises(PaymentProviderError) as exc_info:
        provider.create_subscription(
            user_id=_USER_ID, plan="pro_weekly", amount_cents=1, currency="CAD"
        )
    assert exc_info.value.code == "payment_provider_error"
    assert stub.calls == []  # rejected before any network call


def test_cancel_sends_cancel_at_period_end():
    provider = _provider()
    stub = _ScriptedRequests([{}])
    provider._request = stub
    provider.cancel_subscription(provider_subscription_id="sub_123")
    method, path, kwargs = stub.calls[0]
    assert (method, path) == ("POST", "/subscriptions/sub_123")
    assert kwargs["data"] == {"cancel_at_period_end": "true"}


# ---------------------------------------------------------------------------
# Customer mapping
# ---------------------------------------------------------------------------


def test_customer_created_with_deterministic_idempotency_key_on_search_miss():
    provider = _provider()
    stub = _ScriptedRequests(
        [
            _SEARCH_MISS,
            {"id": "cus_new"},
            {"id": "sub_1", "latest_invoice": {}},
        ]
    )
    provider._request = stub
    provider.create_subscription(
        user_id=_USER_ID, plan="pro_monthly", amount_cents=999, currency="CAD"
    )
    method, path, kwargs = stub.calls[1]
    assert (method, path) == ("POST", "/customers")
    assert kwargs["idempotency_key"] == f"drape-customer-{_USER_ID}"
    assert kwargs["data"] == {
        "metadata[user_id]": str(_USER_ID),
        "metadata[environment]": "tbd",
    }


def test_persisted_customer_id_skips_lookup_entirely():
    provider = _provider()
    stub = _ScriptedRequests([{"id": "sub_1", "latest_invoice": {}}])
    provider._request = stub
    provider.create_subscription(
        user_id=_USER_ID,
        plan="pro_monthly",
        amount_cents=999,
        currency="CAD",
        customer_id="cus_persisted",
    )
    paths = [path for _, path, _ in stub.calls]
    assert paths == ["/subscriptions"]  # no search, no create
    assert stub.calls[0][2]["data"]["customer"] == "cus_persisted"


def test_ensure_customer_hint_is_trusted_without_network():
    provider = _provider()
    stub = _ScriptedRequests([])
    provider._request = stub
    assert (
        provider.ensure_customer(user_id=_USER_ID, customer_id="cus_persisted")
        == "cus_persisted"
    )
    assert stub.calls == []


def test_ensure_customer_refreshes_drifted_identity_on_hit():
    provider = _provider()
    stub = _ScriptedRequests(
        [
            {"data": [{"id": "cus_1", "email": "old@example.com", "metadata": {}}]},
            {},  # the identity update
        ]
    )
    provider._request = stub
    cid = provider.ensure_customer(
        user_id=_USER_ID, email="new@example.com", name="Dev User"
    )
    assert cid == "cus_1"
    method, path, kwargs = stub.calls[1]
    assert (method, path) == ("POST", "/customers/cus_1")
    assert kwargs["data"] == {
        "email": "new@example.com",
        "name": "Dev User",
        "metadata[environment]": "tbd",
    }


def test_ensure_customer_creates_with_full_identity_on_miss():
    provider = _provider()
    stub = _ScriptedRequests([_SEARCH_MISS, {"id": "cus_new"}])
    provider._request = stub
    cid = provider.ensure_customer(
        user_id=_USER_ID, email="dev@example.com", name="Dev User"
    )
    assert cid == "cus_new"
    _, path, kwargs = stub.calls[1]
    assert path == "/customers"
    assert kwargs["data"] == {
        "metadata[user_id]": str(_USER_ID),
        "metadata[environment]": "tbd",
        "email": "dev@example.com",
        "name": "Dev User",
    }


def test_subscription_idempotency_key_forwarded():
    provider = _provider()
    stub = _ScriptedRequests([{"id": "sub_1", "latest_invoice": {}}])
    provider._request = stub
    provider.create_subscription(
        user_id=_USER_ID,
        plan="pro_monthly",
        amount_cents=999,
        currency="CAD",
        customer_id="cus_1",
        idempotency_key="zoura-sub-attempt-1",
    )
    assert stub.calls[0][2]["idempotency_key"] == "zoura-sub-attempt-1"


def test_customer_memoized_across_calls():
    provider = _provider()
    stub = _ScriptedRequests(
        [
            _SEARCH_HIT,
            {"id": "sub_1", "latest_invoice": {}},
            {"id": "sub_2", "latest_invoice": {}},  # no second search
        ]
    )
    provider._request = stub
    provider.create_subscription(
        user_id=_USER_ID, plan="pro_monthly", amount_cents=999, currency="CAD"
    )
    provider.create_subscription(
        user_id=_USER_ID, plan="pro_yearly", amount_cents=7999, currency="CAD"
    )
    paths = [path for _, path, _ in stub.calls]
    assert paths == ["/customers/search", "/subscriptions", "/subscriptions"]


# ---------------------------------------------------------------------------
# Payment methods & portal
# ---------------------------------------------------------------------------


def test_add_payment_method_attaches_and_sets_default():
    provider = _provider()
    pm = {
        "id": "pm_1",
        "card": {"brand": "mastercard", "last4": "5100", "exp_month": 4, "exp_year": 2031},
    }
    stub = _ScriptedRequests([_SEARCH_HIT, pm, {}])
    provider._request = stub

    result = provider.add_payment_method(user_id=_USER_ID, token="pm_1")

    assert result.kind == "card"
    assert (result.brand, result.last4) == ("mastercard", "5100")
    method, path, kwargs = stub.calls[1]
    assert (method, path) == ("POST", "/payment_methods/pm_1/attach")
    method, path, kwargs = stub.calls[2]
    assert (method, path) == ("POST", "/customers/cus_existing")
    assert kwargs["data"] == {"invoice_settings[default_payment_method]": "pm_1"}


def test_apple_pay_wallet_mapped_to_kind():
    provider = _provider()
    pm = {
        "id": "pm_2",
        "card": {
            "brand": "visa",
            "last4": "4242",
            "exp_month": 1,
            "exp_year": 2030,
            "wallet": {"type": "apple_pay"},
        },
    }
    provider._request = _ScriptedRequests([_SEARCH_HIT, pm, {}])
    result = provider.add_payment_method(user_id=_USER_ID, token="pm_2")
    assert result.kind == "apple_pay"


def test_portal_url_returned():
    provider = _provider()
    stub = _ScriptedRequests([_SEARCH_HIT, {"url": "https://billing.stripe.com/p/session_1"}])
    provider._request = stub
    url = provider.create_portal_url(user_id=_USER_ID)
    assert url == "https://billing.stripe.com/p/session_1"
    method, path, kwargs = stub.calls[1]
    assert (method, path) == ("POST", "/billing_portal/sessions")
    assert kwargs["data"]["return_url"] == "zoura://billing"


# ---------------------------------------------------------------------------
# _request error mapping (real httpx layer via MockTransport)
# ---------------------------------------------------------------------------


def _with_transport(monkeypatch, handler) -> StripeProvider:
    real_client = httpx.Client
    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        httpx, "Client", lambda **kwargs: real_client(transport=transport)
    )
    return _provider()


def test_card_error_maps_to_payment_failed(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        assert request.headers["authorization"] == "Bearer sk_test_x"
        return httpx.Response(
            402,
            json={"error": {"type": "card_error", "message": "Your card was declined."}},
        )

    provider = _with_transport(monkeypatch, handler)
    with pytest.raises(PaymentProviderError) as exc_info:
        provider._request("POST", "/subscriptions", data={})
    assert exc_info.value.code == "payment_failed"
    assert "declined" in str(exc_info.value)


def test_api_error_maps_to_provider_error(monkeypatch):
    handler = lambda request: httpx.Response(500, json={"error": {"type": "api_error"}})
    provider = _with_transport(monkeypatch, handler)
    with pytest.raises(PaymentProviderError) as exc_info:
        provider._request("POST", "/subscriptions", data={})
    assert exc_info.value.code == "payment_provider_error"


def test_network_failure_maps_to_provider_error(monkeypatch):
    def handler(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("boom")

    provider = _with_transport(monkeypatch, handler)
    with pytest.raises(PaymentProviderError) as exc_info:
        provider._request("GET", "/customers/search", params={"query": "x"})
    assert exc_info.value.code == "payment_provider_error"


def test_idempotency_key_sent_as_header(monkeypatch):
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["idempotency"] = request.headers.get("idempotency-key")
        return httpx.Response(200, json={"id": "cus_1"})

    provider = _with_transport(monkeypatch, handler)
    provider._request("POST", "/customers", data={}, idempotency_key="drape-customer-x")
    assert seen["idempotency"] == "drape-customer-x"


# ---------------------------------------------------------------------------
# Webhook signature verification
# ---------------------------------------------------------------------------

_SECRET = "whsec_test_secret"


def _sign(payload: bytes, *, secret: str = _SECRET, ts: int | None = None) -> str:
    ts = int(time.time()) if ts is None else ts
    mac = hmac.new(secret.encode(), f"{ts}.".encode() + payload, hashlib.sha256).hexdigest()
    return f"t={ts},v1={mac}"


def test_valid_signature_accepted():
    payload = json.dumps({"type": "invoice.paid"}).encode()
    verify_webhook_signature(payload, _sign(payload), _SECRET)  # no raise


def test_tampered_payload_rejected():
    payload = b'{"type": "invoice.paid"}'
    header = _sign(payload)
    with pytest.raises(PaymentProviderError):
        verify_webhook_signature(b'{"type": "evil"}', header, _SECRET)


def test_wrong_secret_rejected():
    payload = b"{}"
    with pytest.raises(PaymentProviderError):
        verify_webhook_signature(payload, _sign(payload, secret="whsec_other"), _SECRET)


def test_stale_timestamp_rejected():
    payload = b"{}"
    header = _sign(payload, ts=int(time.time()) - 3600)
    with pytest.raises(PaymentProviderError):
        verify_webhook_signature(payload, header, _SECRET)


def test_malformed_header_rejected():
    for header in ("", "t=,v1=", "v1=deadbeef", "t=123"):
        with pytest.raises(PaymentProviderError):
            verify_webhook_signature(b"{}", header, _SECRET)


def test_one_valid_of_multiple_v1_signatures_accepted():
    payload = b"{}"
    valid = _sign(payload)
    header = f"{valid},v1={'0' * 64}"
    verify_webhook_signature(payload, header, _SECRET)  # no raise
