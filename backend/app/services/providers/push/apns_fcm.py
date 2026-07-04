"""Real APNS/FCM delivery — Tier 3.3 / item 11d second half. Blocked on the
FCM/APNS project; mirrors the Stripe/KMS pattern of raising until built."""
from __future__ import annotations

from app.services.providers.push.base import PushProvider


class ApnsFcmProvider(PushProvider):
    def __init__(self, *, fcm_credentials_json: str) -> None:
        self._creds = fcm_credentials_json

    def send(
        self,
        *,
        device_token: str,
        platform: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> None:
        raise NotImplementedError("ApnsFcmProvider lands in 11d (Tier 3.3)")
