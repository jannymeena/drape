"""PushProvider interface (item 11d, framework half).

Same @Profile-style pattern as email: dev logs, prod delivers via APNS/FCM
(Tier 3.3). The service layer talks only to this interface.
"""
from __future__ import annotations

from abc import ABC, abstractmethod


class PushProvider(ABC):
    @abstractmethod
    def send(
        self,
        *,
        device_token: str,
        platform: str,
        title: str,
        body: str,
        data: dict[str, str] | None = None,
    ) -> None:
        """Deliver one notification to one device. Must not raise for
        delivery-level failures (log and move on) — callers treat push as
        fire-and-forget."""
