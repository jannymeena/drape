"""Tier 2.1 — RealOAuthVerifier: JWKS-based Apple/Google identity-token verification.

Tokens are signed with a locally generated RSA key; `_fetch_jwks` is patched to
serve the matching JWKS document, so signature, issuer, audience, expiry,
key-rotation, and cache behaviour are all exercised for real. Only the HTTP
fetch itself is stubbed.
"""
from __future__ import annotations

import asyncio
import time

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa

from app.services.providers.oauth.base import OAuthVerificationError
from app.services.providers.oauth.real import (
    _APPLE_ISSUER,
    _APPLE_JWKS_URL,
    _GOOGLE_JWKS_URL,
    RealOAuthVerifier,
)

_APPLE_AUD = "com.drape.app"
_GOOGLE_AUD_IOS = "ios-client.apps.googleusercontent.com"
_GOOGLE_AUD_ANDROID = "android-client.apps.googleusercontent.com"

_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_ROTATED_KEY = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_KID = "kid-1"
_ROTATED_KID = "kid-2"


def _jwk(private_key, kid: str) -> dict:
    entry = jwt.algorithms.RSAAlgorithm.to_jwk(private_key.public_key(), as_dict=True)
    return {**entry, "kid": kid, "use": "sig", "alg": "RS256"}


def _token(
    *,
    key=_KEY,
    kid: str = _KID,
    iss: str = _APPLE_ISSUER,
    aud: str = _APPLE_AUD,
    sub: str = "sub-123",
    email: str | None = "user@example.com",
    email_verified: object = True,
    expires_in: int = 600,
    algorithm: str = "RS256",
) -> str:
    now = int(time.time())
    claims: dict = {"iss": iss, "aud": aud, "sub": sub, "iat": now, "exp": now + expires_in}
    if email is not None:
        claims["email"] = email
    if email_verified is not None:
        claims["email_verified"] = email_verified
    return jwt.encode(claims, key, algorithm=algorithm, headers={"kid": kid})


@pytest.fixture
def verifier(monkeypatch):
    """A RealOAuthVerifier whose JWKS fetch serves _KEY under _KID for both
    providers. Tests can mutate `jwks_docs` to simulate rotation; `fetches`
    records every fetch for cache assertions."""
    v = RealOAuthVerifier(
        apple_client_id=_APPLE_AUD,
        google_client_id=f"{_GOOGLE_AUD_IOS}, {_GOOGLE_AUD_ANDROID}",
    )
    jwks = {"keys": [_jwk(_KEY, _KID)]}
    jwks_docs = {_APPLE_JWKS_URL: jwks, _GOOGLE_JWKS_URL: jwks}
    fetches: list[str] = []

    async def fake_fetch(url: str) -> dict:
        fetches.append(url)
        return jwks_docs[url]

    monkeypatch.setattr(v, "_fetch_jwks", fake_fetch)
    v.jwks_docs = jwks_docs  # test-only handles
    v.fetches = fetches
    return v


# ---------------------------------------------------------------------------
# Happy paths
# ---------------------------------------------------------------------------


def test_apple_valid_token_returns_claims(verifier):
    claims = asyncio.run(verifier.verify_apple(_token()))
    assert claims["sub"] == "sub-123"
    assert claims["email"] == "user@example.com"


def test_google_valid_token_accepts_both_platform_audiences(verifier):
    for aud in (_GOOGLE_AUD_IOS, _GOOGLE_AUD_ANDROID):
        token = _token(iss="https://accounts.google.com", aud=aud)
        assert asyncio.run(verifier.verify_google(token))["sub"] == "sub-123"


def test_google_issuer_without_scheme_accepted(verifier):
    token = _token(iss="accounts.google.com", aud=_GOOGLE_AUD_IOS)
    assert asyncio.run(verifier.verify_google(token))["sub"] == "sub-123"


def test_apple_string_email_verified_accepted(verifier):
    claims = asyncio.run(verifier.verify_apple(_token(email_verified="true")))
    assert claims["email"] == "user@example.com"


def test_token_without_email_verified_claim_accepted(verifier):
    # email_verified is optional; the service layer enforces sub/email presence.
    assert asyncio.run(verifier.verify_apple(_token(email_verified=None)))


# ---------------------------------------------------------------------------
# Rejections
# ---------------------------------------------------------------------------


def _rejects(verifier_call, *, code: str = "oauth_invalid_token") -> None:
    with pytest.raises(OAuthVerificationError) as exc_info:
        asyncio.run(verifier_call)
    assert exc_info.value.code == code


def test_wrong_audience_rejected(verifier):
    _rejects(verifier.verify_apple(_token(aud="com.evil.app")))


def test_wrong_issuer_rejected(verifier):
    _rejects(verifier.verify_apple(_token(iss="https://evil.example.com")))


def test_google_token_rejected_by_apple_verifier(verifier):
    token = _token(iss="https://accounts.google.com", aud=_GOOGLE_AUD_IOS)
    _rejects(verifier.verify_apple(token))


def test_expired_token_rejected(verifier):
    _rejects(verifier.verify_apple(_token(expires_in=-60)))


def test_signature_from_wrong_key_rejected(verifier):
    # Same kid, different private key — signature check must fail.
    _rejects(verifier.verify_apple(_token(key=_ROTATED_KEY, kid=_KID)))


def test_hs256_token_rejected(verifier):
    # Alg-confusion guard: only RS256 is accepted.
    token = _token(key="shared-secret-of-at-least-32-bytes!!", algorithm="HS256")
    _rejects(verifier.verify_apple(token))


def test_garbage_token_rejected(verifier):
    _rejects(verifier.verify_apple("not-a-jwt"))


def test_missing_kid_rejected(verifier):
    now = int(time.time())
    token = jwt.encode(
        {"iss": _APPLE_ISSUER, "aud": _APPLE_AUD, "sub": "s", "exp": now + 600},
        _KEY,
        algorithm="RS256",
    )
    _rejects(verifier.verify_apple(token))


def test_unverified_email_rejected(verifier):
    _rejects(verifier.verify_apple(_token(email_verified=False)), code="oauth_email_unverified")
    _rejects(verifier.verify_apple(_token(email_verified="false")), code="oauth_email_unverified")


def test_feature_disabled_side_rejected_as_unavailable():
    # No JWKS patching needed — a disabled provider must answer before any fetch.
    v = RealOAuthVerifier(apple_client_id=None, google_client_id=_GOOGLE_AUD_IOS)
    _rejects(v.verify_apple(_token()), code="oauth_unavailable")
    v = RealOAuthVerifier(apple_client_id=_APPLE_AUD, google_client_id=None)
    _rejects(v.verify_google(_token()), code="oauth_unavailable")


# ---------------------------------------------------------------------------
# JWKS cache + rotation
# ---------------------------------------------------------------------------


def test_jwks_fetched_once_across_verifies(verifier):
    asyncio.run(verifier.verify_apple(_token()))
    asyncio.run(verifier.verify_apple(_token(sub="sub-456")))
    assert verifier.fetches == [_APPLE_JWKS_URL]


def test_key_rotation_triggers_refetch(verifier):
    asyncio.run(verifier.verify_apple(_token()))  # primes the cache with kid-1
    verifier.jwks_docs[_APPLE_JWKS_URL] = {"keys": [_jwk(_KEY, _KID), _jwk(_ROTATED_KEY, _ROTATED_KID)]}
    claims = asyncio.run(verifier.verify_apple(_token(key=_ROTATED_KEY, kid=_ROTATED_KID)))
    assert claims["sub"] == "sub-123"
    assert verifier.fetches == [_APPLE_JWKS_URL, _APPLE_JWKS_URL]


def test_unknown_kid_after_refetch_rejected(verifier):
    _rejects(verifier.verify_apple(_token(kid="never-published")))
    assert verifier.fetches == [_APPLE_JWKS_URL]  # refetched once, then gave up
