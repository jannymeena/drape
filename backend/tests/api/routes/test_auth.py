"""Auth route tests — ports the bash 01_auth.sh checks into pytest with
structured assertions, plus a few cases bash didn't cover (password rules,
terms-not-agreed, malformed body).
"""
from __future__ import annotations

import pytest


# ---------------------------------------------------------------------------
# Signup
# ---------------------------------------------------------------------------


def test_signup_with_email_creates_user_and_returns_tokens(client):
    body = {
        "auth_method": "email",
        "email": "fresh@example.com",
        "password": "password1",
        "display_name": "Fresh Test",
        "agreed_to_terms": True,
        "agreed_to_privacy": True,
    }
    r = client.post("/api/v1/auth/signup", json=body)
    assert r.status_code == 201, r.text
    payload = r.json()
    assert payload["email"] == "fresh@example.com"
    assert payload["access_token"]
    assert payload["refresh_token"]
    assert payload["onboarding_completed"] is False
    assert payload["next_step"] == "shopping_style_selection"


def test_signup_duplicate_email_rejected(client, make_user):
    make_user(email="dup@example.com")
    body = {
        "auth_method": "email",
        "email": "dup@example.com",
        "password": "password1",
        "display_name": "Dup",
        "agreed_to_terms": True,
        "agreed_to_privacy": True,
    }
    r = client.post("/api/v1/auth/signup", json=body)
    # Backend may return 400 or 409 depending on implementation; both are
    # acceptable as long as it's not 201 and the message indicates conflict.
    assert r.status_code in (400, 409), r.text


@pytest.mark.parametrize(
    "password,reason",
    [
        ("short1", "too short"),
        ("nodigits", "no digits"),
        ("12345678", "no letters"),
        ("", "empty"),
    ],
)
def test_signup_rejects_weak_password(client, password, reason):
    body = {
        "auth_method": "email",
        "email": f"weak-{reason.replace(' ', '-')}@example.com",
        "password": password,
        "display_name": "Weak",
        "agreed_to_terms": True,
        "agreed_to_privacy": True,
    }
    r = client.post("/api/v1/auth/signup", json=body)
    assert r.status_code == 422, f"expected 422 for {reason!r}, got {r.status_code}: {r.text}"


def test_signup_without_terms_agreed_rejected(client):
    body = {
        "auth_method": "email",
        "email": "no-terms@example.com",
        "password": "password1",
        "display_name": "No Terms",
        "agreed_to_terms": False,
        "agreed_to_privacy": True,
    }
    r = client.post("/api/v1/auth/signup", json=body)
    # The schema doesn't enforce true-only, but the auth_service rejects.
    # Either 400 from service or 422 from schema is acceptable.
    assert r.status_code in (400, 422), r.text


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------


def test_login_with_valid_credentials(client, make_user):
    make_user(email="valid@example.com", password="password1")
    r = client.post(
        "/api/v1/auth/login",
        json={
            "auth_method": "email",
            "email": "valid@example.com",
            "password": "password1",
        },
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["email"] == "valid@example.com"
    assert body["access_token"]
    assert body["refresh_token"]


def test_login_with_wrong_password_returns_401(client, make_user):
    make_user(email="wrong@example.com", password="password1")
    r = client.post(
        "/api/v1/auth/login",
        json={
            "auth_method": "email",
            "email": "wrong@example.com",
            "password": "wrong-password-99",
        },
    )
    assert r.status_code == 401, r.text


def test_login_for_unknown_user_returns_401(client):
    """Same 401 as wrong password — no user-existence oracle."""
    r = client.post(
        "/api/v1/auth/login",
        json={
            "auth_method": "email",
            "email": "ghost@example.com",
            "password": "password1",
        },
    )
    assert r.status_code == 401, r.text


# ---------------------------------------------------------------------------
# Refresh
# ---------------------------------------------------------------------------


def test_refresh_rotates_refresh_token_and_revokes_old(client, make_user):
    """Refresh tokens are opaque random + rotated on every refresh; old token
    is revoked. We don't assert access-token byte-difference because JWT iat
    is whole-seconds — back-to-back calls in tests can produce identical
    tokens, which is correct behaviour."""
    make_user(email="rotate@example.com", password="password1")
    login = client.post(
        "/api/v1/auth/login",
        json={
            "auth_method": "email",
            "email": "rotate@example.com",
            "password": "password1",
        },
    ).json()
    old_refresh = login["refresh_token"]

    r = client.post("/api/v1/auth/refresh-token", json={"refresh_token": old_refresh})
    assert r.status_code == 200, r.text
    body = r.json()
    new_refresh = body["refresh_token"]

    # Refresh token must rotate (old → revoked, new → live).
    assert new_refresh != old_refresh, "refresh token did not rotate"
    assert body["access_token"], "missing access_token in refresh response"

    # Old refresh token is now revoked — using it again must fail.
    r2 = client.post("/api/v1/auth/refresh-token", json={"refresh_token": old_refresh})
    assert r2.status_code == 401, f"old refresh should be revoked, got {r2.status_code}"


def test_refresh_with_garbage_token_returns_401(client):
    r = client.post(
        "/api/v1/auth/refresh-token",
        json={"refresh_token": "definitely-not-a-real-token"},
    )
    assert r.status_code == 401, r.text


# ---------------------------------------------------------------------------
# /users/me round-trip via Bearer header
# ---------------------------------------------------------------------------


def test_users_me_with_valid_token_returns_user(client, make_user, auth_headers):
    user = make_user(email="me@example.com", display_name="Me Test")
    r = client.get("/api/v1/users/me", headers=auth_headers(user))
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["email"] == "me@example.com"
    assert body["display_name"] == "Me Test"


def test_users_me_without_token_returns_401(client):
    r = client.get("/api/v1/users/me")
    assert r.status_code == 401, r.text


def test_users_me_with_garbage_token_returns_401(client):
    r = client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer not-a-real-jwt"},
    )
    assert r.status_code == 401, r.text


# ---------------------------------------------------------------------------
# Forgot / reset password
# ---------------------------------------------------------------------------


def test_forgot_password_with_known_email_returns_202(client, make_user):
    make_user(email="known@example.com")
    r = client.post(
        "/api/v1/auth/forgot-password", json={"email": "known@example.com"}
    )
    assert r.status_code == 202


def test_forgot_password_with_unknown_email_also_returns_202(client):
    """Doesn't leak whether the email exists — same status either way."""
    r = client.post(
        "/api/v1/auth/forgot-password", json={"email": "ghost@example.com"}
    )
    assert r.status_code == 202


def test_reset_password_flow_end_to_end(client, make_user, db):
    """Generate a token via the service helper, persist it, then call the
    /reset-password route with the raw token. Confirms hash matching."""
    from datetime import datetime, timedelta, timezone

    from app.core.security import generate_opaque_token, hash_opaque_token
    from app.db.models import PasswordResetToken

    user = make_user(email="reset@example.com", password="oldpassword1")
    raw, hashed = generate_opaque_token()
    db.add(
        PasswordResetToken(
            user_id=user.id,
            token_hash=hashed,
            expires_at=datetime.now(timezone.utc) + timedelta(hours=1),
            created_at=datetime.now(timezone.utc),
        )
    )
    db.commit()

    r = client.post(
        "/api/v1/auth/reset-password",
        json={"token": raw, "new_password": "newpassword2"},
    )
    assert r.status_code == 204, r.text

    # Confirm login now works with the new password and fails with the old.
    r_old = client.post(
        "/api/v1/auth/login",
        json={"auth_method": "email", "email": "reset@example.com", "password": "oldpassword1"},
    )
    assert r_old.status_code == 401

    r_new = client.post(
        "/api/v1/auth/login",
        json={"auth_method": "email", "email": "reset@example.com", "password": "newpassword2"},
    )
    assert r_new.status_code == 200


def test_reset_password_with_garbage_token_returns_400(client):
    r = client.post(
        "/api/v1/auth/reset-password",
        json={"token": "definitely-not-a-real-token", "new_password": "newpassword2"},
    )
    assert r.status_code == 400


def test_reset_password_rejects_weak_password(client):
    r = client.post(
        "/api/v1/auth/reset-password",
        json={"token": "anything", "new_password": "short"},
    )
    assert r.status_code == 422


# ---------------------------------------------------------------------------
# Logout
# ---------------------------------------------------------------------------


def test_logout_revokes_refresh_token(client, make_user):
    make_user(email="logout@example.com", password="password1")
    login = client.post(
        "/api/v1/auth/login",
        json={"auth_method": "email", "email": "logout@example.com", "password": "password1"},
    ).json()
    refresh = login["refresh_token"]

    r = client.post("/api/v1/auth/logout", json={"refresh_token": refresh})
    assert r.status_code == 204

    # Refresh with the now-revoked token should 401.
    r2 = client.post("/api/v1/auth/refresh-token", json={"refresh_token": refresh})
    assert r2.status_code == 401


def test_logout_idempotent_with_unknown_token(client):
    """Logout with a token we've never seen → 204 (idempotent, no leak)."""
    r = client.post(
        "/api/v1/auth/logout", json={"refresh_token": "totally-not-a-real-token"}
    )
    assert r.status_code == 204


# ---------------------------------------------------------------------------
# OAuth (Tier 2.1) — route plumbing with a stubbed verifier; RealOAuthVerifier
# itself is covered in tests/services/test_oauth_verifier.py.
# ---------------------------------------------------------------------------

from typing import Any

from app.main import app
from app.api.dependencies.providers import get_oauth_verifier
from app.services.providers.oauth.base import OAuthVerificationError, OAuthVerifier


class _StubOAuthVerifier(OAuthVerifier):
    def __init__(
        self,
        claims: dict[str, Any] | None = None,
        error: OAuthVerificationError | None = None,
    ) -> None:
        self.claims = claims or {"sub": "oauth-sub-1", "email": "oauth@example.com"}
        self.error = error

    async def _result(self) -> dict[str, Any]:
        if self.error is not None:
            raise self.error
        return self.claims

    async def verify_apple(self, id_token: str) -> dict[str, Any]:
        return await self._result()

    async def verify_google(self, id_token: str) -> dict[str, Any]:
        return await self._result()


@pytest.fixture
def oauth_client(client):
    """The standard client with a stub OAuth verifier mounted. Yields
    (client, stub); the `client` fixture clears all overrides on teardown."""
    stub = _StubOAuthVerifier()
    app.dependency_overrides[get_oauth_verifier] = lambda: stub
    return client, stub


def test_oauth_login_unavailable_in_dev(client):
    # No override: with a keyless .env the dev container wires oauth=None;
    # with a Google-only .env the Apple side has no audience. Either path
    # answers 400 oauth_unavailable, not 404/500.
    r = client.post(
        "/api/v1/auth/login",
        json={"auth_method": "apple", "apple_id_token": "some-token"},
    )
    assert r.status_code == 400, r.text
    assert r.json()["detail"]["code"] == "oauth_unavailable"


def test_oauth_signup_creates_user(oauth_client):
    client, _ = oauth_client
    r = client.post(
        "/api/v1/auth/signup",
        json={
            "auth_method": "apple",
            "apple_id_token": "stub-token",
            "agreed_to_terms": True,
            "agreed_to_privacy": True,
        },
    )
    assert r.status_code == 201, r.text
    payload = r.json()
    assert payload["email"] == "oauth@example.com"
    assert payload["access_token"]
    assert payload["onboarding_completed"] is False


def test_oauth_login_is_idempotent_upsert(oauth_client):
    client, _ = oauth_client
    body = {"auth_method": "google", "google_id_token": "stub-token"}
    first = client.post("/api/v1/auth/login", json=body)
    second = client.post("/api/v1/auth/login", json=body)
    assert first.status_code == 200 and second.status_code == 200
    assert first.json()["user_id"] == second.json()["user_id"]


def test_oauth_login_links_existing_email_account(oauth_client, make_user):
    client, stub = oauth_client
    existing = make_user(email="linkme@example.com")
    stub.claims = {"sub": "google-sub-9", "email": "linkme@example.com"}
    r = client.post(
        "/api/v1/auth/login", json={"auth_method": "google", "google_id_token": "stub-token"}
    )
    assert r.status_code == 200, r.text
    assert r.json()["user_id"] == str(existing.id)


def test_oauth_invalid_token_returns_401(oauth_client):
    client, stub = oauth_client
    stub.error = OAuthVerificationError("oauth_invalid_token", "Token verification failed")
    r = client.post(
        "/api/v1/auth/login", json={"auth_method": "apple", "apple_id_token": "bad-token"}
    )
    assert r.status_code == 401, r.text
    assert r.json()["detail"]["code"] == "oauth_invalid_token"


def test_oauth_feature_disabled_returns_400_on_login(oauth_client):
    client, stub = oauth_client
    stub.error = OAuthVerificationError("oauth_unavailable", "Apple sign-in is disabled")
    r = client.post(
        "/api/v1/auth/login", json={"auth_method": "apple", "apple_id_token": "stub-token"}
    )
    assert r.status_code == 400, r.text
    assert r.json()["detail"]["code"] == "oauth_unavailable"


def test_oauth_feature_disabled_returns_400_on_signup(oauth_client):
    client, stub = oauth_client
    stub.error = OAuthVerificationError("oauth_unavailable", "Google sign-in is disabled")
    r = client.post(
        "/api/v1/auth/signup",
        json={
            "auth_method": "google",
            "google_id_token": "stub-token",
            "agreed_to_terms": True,
            "agreed_to_privacy": True,
        },
    )
    assert r.status_code == 400, r.text
    assert r.json()["detail"]["code"] == "oauth_unavailable"


def test_oauth_missing_claims_returns_401(oauth_client):
    client, stub = oauth_client
    stub.claims = {"sub": "no-email-sub"}  # e.g. provider returned no email
    r = client.post(
        "/api/v1/auth/login", json={"auth_method": "apple", "apple_id_token": "stub-token"}
    )
    assert r.status_code == 401, r.text
    assert r.json()["detail"]["code"] == "oauth_missing_claims"
