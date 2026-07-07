from __future__ import annotations

import time
from typing import Any

import httpx
import jwt
import structlog

from app.services.providers.oauth.base import OAuthVerificationError, OAuthVerifier

_log = structlog.get_logger("provider.oauth.real")

_APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
_APPLE_ISSUER = "https://appleid.apple.com"
_GOOGLE_JWKS_URL = "https://www.googleapis.com/oauth2/v3/certs"
# Google tokens carry either form depending on the client library.
_GOOGLE_ISSUERS = ["https://accounts.google.com", "accounts.google.com"]

_TIMEOUT_S = 10.0
_JWKS_TTL_S = 3600.0


def _split_audiences(client_id: str | None) -> list[str]:
    if not client_id:
        return []
    return [a.strip() for a in client_id.split(",") if a.strip()]


class RealOAuthVerifier(OAuthVerifier):
    """Verifies Apple/Google identity tokens against the providers' JWKS.

    Client IDs may be comma-separated: Google issues distinct client IDs per
    platform (iOS/Android), and Apple tokens carry the bundle ID (native flow)
    or the Service ID (web flow) as audience. A None client ID means the
    provider is feature-disabled (DISABLED_FEATURES) — its verify answers
    oauth_unavailable.
    """

    def __init__(self, *, apple_client_id: str | None, google_client_id: str | None) -> None:
        self._apple_audiences = _split_audiences(apple_client_id)
        self._google_audiences = _split_audiences(google_client_id)
        # JWKS URL -> (fetched_at monotonic, kid -> parsed key)
        self._jwks_cache: dict[str, tuple[float, dict[str, Any]]] = {}

    async def verify_apple(self, id_token: str) -> dict[str, Any]:
        if not self._apple_audiences:
            raise OAuthVerificationError("oauth_unavailable", "Apple sign-in is disabled")
        return await self._verify(
            id_token,
            jwks_url=_APPLE_JWKS_URL,
            issuer=_APPLE_ISSUER,
            audiences=self._apple_audiences,
        )

    async def verify_google(self, id_token: str) -> dict[str, Any]:
        if not self._google_audiences:
            raise OAuthVerificationError("oauth_unavailable", "Google sign-in is disabled")
        return await self._verify(
            id_token,
            jwks_url=_GOOGLE_JWKS_URL,
            issuer=_GOOGLE_ISSUERS,
            audiences=self._google_audiences,
        )

    async def _verify(
        self,
        id_token: str,
        *,
        jwks_url: str,
        issuer: str | list[str],
        audiences: list[str],
    ) -> dict[str, Any]:
        try:
            header = jwt.get_unverified_header(id_token)
        except jwt.PyJWTError as exc:
            raise OAuthVerificationError("oauth_invalid_token", f"Malformed token: {exc}") from exc

        kid = header.get("kid")
        if not kid:
            raise OAuthVerificationError("oauth_invalid_token", "Token header has no key id")

        key = await self._signing_key(jwks_url, kid)
        try:
            claims: dict[str, Any] = jwt.decode(
                id_token,
                key=key,
                algorithms=["RS256"],
                audience=audiences,
                issuer=issuer,
                options={"require": ["exp", "iss", "aud", "sub"]},
            )
        except jwt.PyJWTError as exc:
            _log.warning("oauth.verify.rejected", jwks_url=jwks_url, error=str(exc))
            raise OAuthVerificationError(
                "oauth_invalid_token", f"Token verification failed: {exc}"
            ) from exc

        # Apple sends email_verified as bool or the string "true"/"false"; Google as bool.
        email_verified = claims.get("email_verified")
        if email_verified is not None and str(email_verified).lower() != "true":
            raise OAuthVerificationError(
                "oauth_email_unverified", "OAuth account email is not verified"
            )
        return claims

    async def _signing_key(self, jwks_url: str, kid: str) -> Any:
        cached = self._jwks_cache.get(jwks_url)
        fresh = cached is not None and time.monotonic() - cached[0] < _JWKS_TTL_S
        if not fresh or kid not in cached[1]:
            # Stale, empty, or unknown kid (key rotation) — refetch once.
            keys = self._parse_jwks(await self._fetch_jwks(jwks_url))
            self._jwks_cache[jwks_url] = (time.monotonic(), keys)
        key = self._jwks_cache[jwks_url][1].get(kid)
        if key is None:
            raise OAuthVerificationError("oauth_invalid_token", "Unknown signing key id")
        return key

    async def _fetch_jwks(self, jwks_url: str) -> dict[str, Any]:
        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_S) as client:
                resp = await client.get(jwks_url)
                resp.raise_for_status()
                return resp.json()
        except (httpx.HTTPError, ValueError) as exc:
            _log.warning("oauth.jwks.fetch_failed", jwks_url=jwks_url, error=str(exc))
            raise OAuthVerificationError(
                "oauth_jwks_unavailable", f"Could not fetch signing keys: {exc}"
            ) from exc

    @staticmethod
    def _parse_jwks(jwks: dict[str, Any]) -> dict[str, Any]:
        keys: dict[str, Any] = {}
        for entry in jwks.get("keys", []):
            kid = entry.get("kid")
            if not kid:
                continue
            try:
                keys[kid] = jwt.PyJWK.from_dict(entry).key
            except jwt.PyJWKError as exc:
                _log.warning("oauth.jwks.bad_key", kid=kid, error=str(exc))
        return keys
