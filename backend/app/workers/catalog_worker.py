"""Catalog worker — keeps `products` in step with the affiliate feed.

Started from the app lifespan (main.py). One asyncio task per process:

- sync on start, then every `SYNC_INTERVAL_S` (the AWIN feeds refresh daily);
  a failed sync retries after `SYNC_RETRY_S`, and an emptied table (a dev DB
  reset under a running server) is re-synced within `SYNC_RETRY_S`. The sync (a blocking multi-second
  feed download + DB diff) runs in a thread so requests keep flowing.
- between syncs, tag one untagged product every `TAG_INTERVAL_S`, idling
  `IDLE_S` when there's nothing to tag and backing off `AI_BACKOFF_S` after
  an AI outage — never a burst of AI calls.

Several processes are safe: the sync takes a Postgres advisory lock and
tagging claims rows with SKIP LOCKED.
"""
from __future__ import annotations

import asyncio
import time
from typing import Callable

import structlog
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import Product

from app.services import catalog_service
from app.services.providers.affiliate.base import AffiliateProvider
from app.services.providers.ai.base import AIProvider, AIProviderError

_log = structlog.get_logger("catalog.worker")

SYNC_INTERVAL_S = 6 * 3600
SYNC_RETRY_S = 300
TAG_INTERVAL_S = 3
IDLE_S = 60
AI_BACKOFF_S = 120


class CatalogWorker:
    def __init__(
        self,
        *,
        session_factory: Callable[[], Session],
        affiliate: AffiliateProvider,
        ai: AIProvider,
        tag_model: str | None,
        advertiser_genders: dict[str, str],
    ) -> None:
        self._session_factory = session_factory
        self._affiliate = affiliate
        self._ai = ai
        self._tag_model = tag_model
        self._genders = advertiser_genders

    def _sync_once(self) -> bool:
        db = self._session_factory()
        try:
            catalog_service.sync_catalog(
                db, affiliate=self._affiliate, advertiser_genders=self._genders
            )
            return True
        except Exception as exc:  # noqa: BLE001 — keep the loop alive
            db.rollback()
            _log.warning("catalog.sync_failed", error=str(exc))
            return False
        finally:
            db.close()

    def _catalog_empty(self) -> bool:
        db = self._session_factory()
        try:
            return db.scalar(select(Product.id).limit(1)) is None
        finally:
            db.close()

    async def _tag_once(self) -> float:
        """Tag one product; returns how long to sleep before the next try."""
        db = self._session_factory()
        try:
            row = await catalog_service.tag_next(db, ai=self._ai, model=self._tag_model)
            return TAG_INTERVAL_S if row is not None else IDLE_S
        except AIProviderError as exc:
            _log.warning("catalog.tag_ai_failed", code=exc.code, error=str(exc))
            return AI_BACKOFF_S
        except Exception as exc:  # noqa: BLE001
            db.rollback()
            _log.warning("catalog.tag_failed", error=str(exc))
            return AI_BACKOFF_S
        finally:
            db.close()

    async def run(self) -> None:
        next_sync = 0.0
        last_sync = 0.0
        while True:
            now = time.monotonic()
            due = now >= next_sync or (
                now - last_sync >= SYNC_RETRY_S and await asyncio.to_thread(self._catalog_empty)
            )
            if due:
                ok = await asyncio.to_thread(self._sync_once)
                last_sync = time.monotonic()
                next_sync = last_sync + (SYNC_INTERVAL_S if ok else SYNC_RETRY_S)
            delay = await self._tag_once()
            await asyncio.sleep(delay)
