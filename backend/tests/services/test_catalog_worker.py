"""CatalogWorker — one sync + tag step against the test DB, and back-off
delays after failures (the loop itself is `while True` and not run here)."""
from __future__ import annotations

from app.workers import catalog_worker
from app.workers.catalog_worker import CatalogWorker
from tests.services.test_catalog_service import _Feed, _p, _rows, _TagAI


def _worker(session_factory, feed, ai) -> CatalogWorker:
    return CatalogWorker(
        session_factory=session_factory, affiliate=feed, ai=ai,
        tag_model=None, advertiser_genders={"60703": "women"},
    )


async def test_sync_then_tag_one_at_a_time(session_factory, db):
    worker = _worker(session_factory, _Feed(_p("a"), _p("b")), _TagAI())
    assert worker._sync_once() is True
    assert await worker._tag_once() == catalog_worker.TAG_INTERVAL_S
    assert sum(1 for p in _rows(db).values() if p.tagged_at) == 1
    assert await worker._tag_once() == catalog_worker.TAG_INTERVAL_S
    assert await worker._tag_once() == catalog_worker.IDLE_S  # nothing left


async def test_failures_back_off_instead_of_crashing(session_factory):
    class _Down(_Feed):
        def catalog(self):
            raise RuntimeError("feed down")

    worker = _worker(session_factory, _Down(), _TagAI(fail=True))
    assert worker._sync_once() is False
    ok = _worker(session_factory, _Feed(_p("a")), _TagAI(fail=True))
    ok._sync_once()
    assert await ok._tag_once() == catalog_worker.AI_BACKOFF_S
