"""Real push delivery via FCM HTTP v1 (item 11d, delivery half).

FCM is the single front door: it delivers to Android directly and relays iOS
messages to APNS (the APNS .p8 key lives in the Firebase project settings).
Auth is a Google service-account OAuth token minted locally — an RS256 JWT
signed with pyjwt, exchanged at the token endpoint — so no google-auth /
firebase-admin dependency.

Per the PushProvider contract, send() NEVER raises: push is fire-and-forget
and a delivery failure must not break the request that triggered it. The one
exception is construction — malformed credentials fail at startup, per the
fail-fast config convention.
"""
from __future__ import annotations

import base64
import json
import threading
import time
from typing import Any

import httpx
import jwt
import structlog

from app.services.providers.push.base import PushProvider

_log = structlog.get_logger("push.fcm")

_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_GRANT_TYPE = "urn:ietf:params:oauth:grant-type:jwt-bearer"
_TIMEOUT_S = 10.0
_TOKEN_EARLY_REFRESH_S = 60.0

_REQUIRED_FIELDS = ("project_id", "client_email", "private_key", "token_uri")


class ApnsFcmProvider(PushProvider):
    def __init__(self, *, fcm_credentials_json: str) -> None:
        creds = self._parse_credentials(fcm_credentials_json)
        self._project_id: str = creds["project_id"]
        self._client_email: str = creds["client_email"]
        self._private_key: str = creds["private_key"]
        self._token_uri: str = creds["token_uri"]
        self._send_url = (
            f"https://fcm.googleapis.com/v1/projects/{self._project_id}/messages:send"
        )
        self._access_token: str | None = None
        self._token_expires_at = 0.0
        self._token_lock = threading.Lock()

    @staticmethod
    def _parse_credentials(raw: str) -> dict[str, Any]:
        """Accept the service-account JSON verbatim or base64-encoded — the
        .env envelope is line-based, so base64 is the transport-safe form."""
        try:
            creds = json.loads(raw)
        except ValueError:
            try:
                creds = json.loads(base64.b64decode(raw, validate=True))
            except ValueError as exc:
                raise ValueError(
                    "FCM_CREDENTIALS_JSON is neither JSON nor base64-encoded JSON"
                ) from exc
        missing = [field for field in _REQUIRED_FIELDS if not creds.get(field)]
        if missing:
            raise ValueError(
                f"FCM service-account JSON is missing fields: {', '.join(missing)}"
            )
        return creds

    def send(
        self,
        *,
        device_token: str,
        platform: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> None:
        try:
            access_token = self._get_access_token()
            message = {
                "message": {
                    "token": device_token,
                    "notification": {"title": title, "body": body},
                    "data": data or {},
                }
            }
            with httpx.Client(timeout=_TIMEOUT_S) as client:
                resp = client.post(
                    self._send_url,
                    headers={"Authorization": f"Bearer {access_token}"},
                    json=message,
                )
            if resp.status_code == 404:
                # Dead token (UNREGISTERED) — logged distinctly so a future
                # pruning pass can act on it.
                _log.warning(
                    "push.fcm.unregistered",
                    platform=platform,
                    device_token=device_token[:12] + "…",
                )
                return
            if resp.status_code >= 400:
                _log.warning(
                    "push.fcm.rejected",
                    platform=platform,
                    status=resp.status_code,
                    detail=resp.text[:200],
                )
                return
            _log.info(
                "push.fcm.sent", platform=platform, message_id=resp.json().get("name")
            )
        except Exception:  # noqa: BLE001 — contract: send never raises
            _log.exception("push.fcm.send_failed", platform=platform)

    def _get_access_token(self) -> str:
        with self._token_lock:
            if (
                self._access_token
                and time.time() < self._token_expires_at - _TOKEN_EARLY_REFRESH_S
            ):
                return self._access_token
            now = int(time.time())
            assertion = jwt.encode(
                {
                    "iss": self._client_email,
                    "scope": _SCOPE,
                    "aud": self._token_uri,
                    "iat": now,
                    "exp": now + 3600,
                },
                self._private_key,
                algorithm="RS256",
            )
            with httpx.Client(timeout=_TIMEOUT_S) as client:
                resp = client.post(
                    self._token_uri,
                    data={"grant_type": _GRANT_TYPE, "assertion": assertion},
                )
                resp.raise_for_status()
                payload = resp.json()
            self._access_token = payload["access_token"]
            self._token_expires_at = time.time() + float(payload.get("expires_in", 3600))
            return self._access_token
