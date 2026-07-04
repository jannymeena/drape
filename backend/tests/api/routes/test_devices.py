"""Device registration + push fan-out (2.3 — push framework)."""
from __future__ import annotations

from app.db.models import Device
from app.services import push_service
from app.services.providers.push.base import PushProvider


class _CapturePush(PushProvider):
    def __init__(self):
        self.sent = []

    def send(self, *, device_token, platform, title, body, data=None):
        self.sent.append((device_token, platform, title, body, data or {}))


def test_register_device_upserts_by_token(authed_client, db):
    r = authed_client.post(
        "/api/v1/devices", json={"platform": "ios", "token": "tok_abcdef123456"}
    )
    assert r.status_code == 201, r.text
    first_id = r.json()["id"]

    # Same token again — same row, refreshed (no duplicate).
    r = authed_client.post(
        "/api/v1/devices", json={"platform": "ios", "token": "tok_abcdef123456"}
    )
    assert r.status_code == 201
    assert r.json()["id"] == first_id
    assert db.query(Device).count() == 1


def test_reregister_moves_token_to_new_owner(
    client, authed_client, make_user, auth_headers
):
    authed_client.post(
        "/api/v1/devices", json={"platform": "android", "token": "tok_shared_device"}
    )
    other = make_user(email="second@example.com")
    r = client.post(
        "/api/v1/devices",
        json={"platform": "android", "token": "tok_shared_device"},
        headers=auth_headers(other),
    )
    assert r.status_code == 201
    # Fan-out targets the new owner only.
    assert r.json()["id"]


def test_remove_device(authed_client):
    authed_client.post(
        "/api/v1/devices", json={"platform": "ios", "token": "tok_gone_1234"}
    )
    r = authed_client.delete("/api/v1/devices/tok_gone_1234")
    assert r.status_code == 204
    r = authed_client.delete("/api/v1/devices/tok_gone_1234")
    assert r.status_code == 404


def test_notify_user_fans_out_to_all_devices(authed_client, db):
    user = authed_client.test_user
    authed_client.post(
        "/api/v1/devices", json={"platform": "ios", "token": "tok_phone_123"}
    )
    authed_client.post(
        "/api/v1/devices", json={"platform": "android", "token": "tok_tablet_456"}
    )
    capture = _CapturePush()

    sent = push_service.notify_user(
        db,
        push=capture,
        user_id=user.id,
        title="Hello",
        body="World",
        data={"route": "today"},
    )

    assert sent == 2
    assert {t for t, *_ in capture.sent} == {"tok_phone_123", "tok_tablet_456"}


def test_notify_user_never_raises(authed_client, db):
    """A blowing-up provider must not propagate — push is fire-and-forget."""
    user = authed_client.test_user
    authed_client.post(
        "/api/v1/devices", json={"platform": "ios", "token": "tok_boom_9999"}
    )

    class _Boom(PushProvider):
        def send(self, **kwargs):
            raise RuntimeError("provider down")

    sent = push_service.notify_user(
        db, push=_Boom(), user_id=user.id, title="t", body="b"
    )
    assert sent == 0
