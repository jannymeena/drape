"""Dev push provider — logs instead of delivering (mirrors LogEmailProvider)."""
from __future__ import annotations

import structlog

from app.services.providers.push.base import PushProvider

_log = structlog.get_logger("push")


class LogPushProvider(PushProvider):
    def send(
        self,
        *,
        device_token: str,
        platform: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> None:
        _log.info(
            "push.log",
            device_token=device_token[:12] + "…",
            platform=platform,
            title=title,
            body=body,
            data=data or {},
        )
