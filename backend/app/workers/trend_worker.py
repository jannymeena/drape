"""Trend worker — keeps a fresh weekly trend brief per audience.

Started from the app lifespan (main.py) when a real AI provider is configured.
Checks every `CHECK_INTERVAL_S` whether a brief is `trend_service.REFRESH_AFTER`
old and researches a new one if so (a minute or two of web search per brief).
A failed research is retried after `RETRY_S`; the prompts keep using the
previous brief until it is `trend_service.MAX_AGE` old.
"""
from __future__ import annotations

import asyncio
import time
from datetime import datetime, timezone
from typing import Callable

import structlog
from sqlalchemy.orm import Session

from app.services import trend_service
from app.services.providers.ai.base import AIProvider, AIProviderError

_log = structlog.get_logger("trends.worker")

CHECK_INTERVAL_S = 3600
RETRY_S = 6 * 3600


class TrendWorker:
    def __init__(
        self, *, session_factory: Callable[[], Session], ai: AIProvider, model: str
    ) -> None:
        self._session_factory = session_factory
        self._ai = ai
        self._model = model
        self._retry_at: dict[str, float] = {}

    async def refresh_once(self) -> None:
        """One pass over every audience; never raises."""
        for audience in trend_service.AUDIENCES:
            if time.monotonic() < self._retry_at.get(audience, 0.0):
                continue
            db = self._session_factory()
            try:
                await trend_service.refresh_if_due(
                    db,
                    ai=self._ai,
                    audience=audience,
                    model=self._model,
                    now=datetime.now(timezone.utc),
                )
            except Exception as exc:  # noqa: BLE001 — keep the loop alive
                db.rollback()
                code = exc.code if isinstance(exc, AIProviderError) else "error"
                _log.warning("trends.refresh_failed", audience=audience, code=code, error=str(exc))
                self._retry_at[audience] = time.monotonic() + RETRY_S
            finally:
                db.close()

    async def run(self) -> None:
        while True:
            await self.refresh_once()
            await asyncio.sleep(CHECK_INTERVAL_S)
