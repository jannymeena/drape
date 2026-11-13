"""Image worker — makes the wardrobe items' mannequin shots and cut-outs
off the upload's request path (image_job_service).

Started from the app lifespan (main.py), one asyncio task per process. Takes
one due job at a time and pauses `PACE_S` between them, so uploads in quick
succession reach the image model as a steady trickle; idles `IDLE_S` when
the queue is empty. Several processes are safe: jobs are claimed with SKIP
LOCKED.
"""

from __future__ import annotations

import asyncio
from typing import Callable

import structlog
from sqlalchemy.orm import Session

from app.services import image_job_service
from app.services.providers.background_removal.base import BackgroundRemover
from app.services.providers.garment_image.base import GarmentImageProvider
from app.services.providers.image.base import ImageStorageProvider

_log = structlog.get_logger("image.worker")

PACE_S = 3.0
IDLE_S = 5.0


class ImageWorker:
    def __init__(
        self,
        *,
        session_factory: Callable[[], Session],
        storage: ImageStorageProvider,
        garment_images: GarmentImageProvider,
        remover: BackgroundRemover,
    ) -> None:
        self._session_factory = session_factory
        self._storage = storage
        self._garment_images = garment_images
        self._remover = remover

    async def run_once(self) -> bool:
        """Works one due job; False when there was none."""
        db = self._session_factory()
        try:
            job = image_job_service.claim_next(db)
            if job is None:
                return False
            await image_job_service.process(
                db,
                job,
                storage=self._storage,
                garment_images=self._garment_images,
                remover=self._remover,
            )
            return True
        finally:
            db.close()

    async def run(self) -> None:
        db = self._session_factory()
        try:
            requeued = image_job_service.requeue_stale(db)
        finally:
            db.close()
        _log.info("image.worker.started", requeued=requeued)
        while True:
            try:
                worked = await self.run_once()
            except asyncio.CancelledError:
                raise
            except Exception as exc:  # noqa: BLE001 — keep the loop alive
                _log.warning("image.worker.error", error=str(exc))
                worked = False
            await asyncio.sleep(PACE_S if worked else IDLE_S)
