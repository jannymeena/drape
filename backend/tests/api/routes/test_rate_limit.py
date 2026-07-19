"""Route-level rate limiting on the auth endpoints (§3.1 hardening).

The limit is 0 (off) in tests by default; each test here turns it on via the
live settings object and resets the module limiter so tests stay independent.
"""
from __future__ import annotations

import pytest

from app.core import rate_limit
from app.core.config import settings


@pytest.fixture
def small_limit():
    original = settings.auth_rate_limit_per_minute
    settings.auth_rate_limit_per_minute = 3
    rate_limit._limiter.reset()
    yield 3
    settings.auth_rate_limit_per_minute = original
    rate_limit._limiter.reset()


def _login(client, email="ratelimit@example.com"):
    return client.post(
        "/api/v1/auth/login",
        json={"auth_method": "email", "email": email, "password": "wrong-password-1"},
    )


def test_login_throttles_after_limit(client, small_limit):
    for _ in range(small_limit):
        assert _login(client).status_code == 401  # wrong creds, but not throttled
    r = _login(client)
    assert r.status_code == 429
    assert r.json()["detail"]["code"] == "rate_limited"


def test_forgot_password_throttles_after_limit(client, small_limit):
    for _ in range(small_limit):
        r = client.post(
            "/api/v1/auth/forgot-password", json={"email": "nobody@example.com"}
        )
        assert r.status_code == 202
    r = client.post("/api/v1/auth/forgot-password", json={"email": "nobody@example.com"})
    assert r.status_code == 429


def test_scopes_do_not_share_buckets(client, small_limit):
    # Exhaust login; forgot-password (same IP, different scope) must still work.
    for _ in range(small_limit + 1):
        _login(client)
    r = client.post("/api/v1/auth/forgot-password", json={"email": "nobody@example.com"})
    assert r.status_code == 202


def test_limit_off_means_no_throttle(client):
    rate_limit._limiter.reset()
    assert settings.auth_rate_limit_per_minute == 0  # test default: off
    for _ in range(10):
        assert _login(client).status_code == 401


def test_forwarded_for_separates_clients(client, small_limit):
    for _ in range(small_limit + 1):
        client.post(
            "/api/v1/auth/forgot-password",
            json={"email": "nobody@example.com"},
            headers={"x-forwarded-for": "203.0.113.7"},
        )
    # A different forwarded client is not throttled by the first one's bucket.
    r = client.post(
        "/api/v1/auth/forgot-password",
        json={"email": "nobody@example.com"},
        headers={"x-forwarded-for": "203.0.113.8"},
    )
    assert r.status_code == 202
