from typing import Any

from app.services.providers.oauth.base import OAuthVerifier


class RealOAuthVerifier(OAuthVerifier):
    def __init__(self, *, apple_client_id: str, google_client_id: str) -> None:
        self._apple_client_id = apple_client_id
        self._google_client_id = google_client_id

    async def verify_apple(self, id_token: str) -> dict[str, Any]:
        raise NotImplementedError("Apple OAuth verification is wired in Phase 4 step 4")

    async def verify_google(self, id_token: str) -> dict[str, Any]:
        raise NotImplementedError("Google OAuth verification is wired in Phase 4 step 4")
