"""Images made for wardrobe items in the background, not on the upload.

An upload stores the photos and returns. Each new photo gets a job for its
ghost-mannequin shot (while the item has room for it), and the item a job
for its folded cut-out if it has none. The image worker
(workers/image_worker.py) works through them one at a time, so a batch of
uploads never turns into a burst of image calls — and when one fails
(Google busy, a backdrop that won't key) it's tried again later, a little
longer each time, until the attempts run out.

Jobs live in `image_jobs`, so a restart loses nothing: one caught running
when the process stopped goes back in the queue on the next start.
"""

from __future__ import annotations

import io
from datetime import datetime, timedelta, timezone
from typing import Literal

import structlog
from PIL import Image
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.db.models import ImageJob, WardrobeItem
from app.services import cutout_service
from app.services.providers.background_removal.base import BackgroundRemover
from app.services.providers.garment_image.base import (
    GarmentImageError,
    GarmentImageProvider,
)
from app.services.providers.image.base import ImageStorageProvider

_log = structlog.get_logger("image_jobs")

JobKind = Literal["mannequin", "cutout"]
JobStatus = Literal["pending", "running", "done", "failed"]

# What the image model is asked to make of each garment photo.
GHOST_MANNEQUIN_PROMPT = (
    "Display your garment on a 3D ghost mannequin with professional styling"
)

# The wait before each retry (after the 1st failure, the 2nd, …); one try
# more than there are waits, then the job is given up.
RETRY_WAITS = (
    timedelta(seconds=30),
    timedelta(minutes=2),
    timedelta(minutes=10),
    timedelta(minutes=30),
    timedelta(hours=2),
)
MAX_ATTEMPTS = len(RETRY_WAITS) + 1


class JobFailed(Exception):
    """This try didn't produce the image; the job is retried later."""


def _now() -> datetime:
    return datetime.now(timezone.utc)


# ---------------------------------------------------------------------------
# Queueing (on upload)
# ---------------------------------------------------------------------------


def enqueue_for_upload(
    db: Session, *, item: WardrobeItem, photo_urls: list[str], max_images: int
) -> list[ImageJob]:
    """Queues the images for photos just added to [item]: a mannequin shot
    for each, while the item has room (the shots count toward [max_images],
    as do shots still queued), and the cut-out from the first photo when the
    item has none and none is queued."""
    pending = list(
        db.scalars(
            select(ImageJob).where(
                ImageJob.item_id == item.id,
                ImageJob.status.in_(("pending", "running")),
            )
        ).all()
    )
    queued_shots = sum(1 for j in pending if j.kind == "mannequin")
    room = max_images - len(item.images or []) - queued_shots

    jobs: list[ImageJob] = []
    for url in photo_urls:
        if room <= 0:
            break
        jobs.append(_job(item, "mannequin", url))
        room -= 1
    cutout_queued = any(j.kind == "cutout" for j in pending)
    if photo_urls and not item.cutout_url and not cutout_queued:
        jobs.append(_job(item, "cutout", photo_urls[0]))

    db.add_all(jobs)
    db.commit()
    if jobs:
        _log.info(
            "image_jobs.queued",
            user_id=str(item.user_id),
            item_id=str(item.id),
            kinds=[j.kind for j in jobs],
        )
    return jobs


def enqueue_cutout(db: Session, *, item: WardrobeItem) -> ImageJob | None:
    """Queues [item]'s cut-out from its own photo (the last image — a
    mannequin shot goes before its photo), unless it has one or one is
    queued. For items that missed theirs."""
    if item.cutout_url or not item.images:
        return None
    queued = db.scalar(
        select(ImageJob.id).where(
            ImageJob.item_id == item.id,
            ImageJob.kind == "cutout",
            ImageJob.status.in_(("pending", "running")),
        )
    )
    if queued:
        return None
    job = _job(item, "cutout", item.images[-1])
    db.add(job)
    db.commit()
    return job


def _job(item: WardrobeItem, kind: JobKind, url: str) -> ImageJob:
    return ImageJob(
        user_id=item.user_id,
        item_id=item.id,
        kind=kind,
        source_url=url,
        status="pending",
        attempts=0,
        next_attempt_at=_now(),
    )


# ---------------------------------------------------------------------------
# Working the queue (the worker)
# ---------------------------------------------------------------------------


def requeue_stale(db: Session) -> int:
    """Jobs left `running` by a process that stopped mid-way go back in the
    queue. Called once when the worker starts."""
    result = db.execute(
        update(ImageJob)
        .where(ImageJob.status == "running")
        .values(status="pending", next_attempt_at=_now())
    )
    db.commit()
    return result.rowcount or 0


def claim_next(db: Session) -> ImageJob | None:
    """The oldest job that's due, marked running — or None. SKIP LOCKED, so
    several workers never take the same one."""
    job = db.scalars(
        select(ImageJob)
        .where(ImageJob.status == "pending", ImageJob.next_attempt_at <= _now())
        .order_by(ImageJob.next_attempt_at, ImageJob.created_at)
        .limit(1)
        .with_for_update(skip_locked=True)
    ).first()
    if job is None:
        db.rollback()
        return None
    job.status = "running"
    job.attempts += 1
    db.commit()
    return job


async def process(
    db: Session,
    job: ImageJob,
    *,
    storage: ImageStorageProvider,
    garment_images: GarmentImageProvider,
    remover: BackgroundRemover,
) -> None:
    """Makes [job]'s image and puts it on the item; a failure schedules the
    next try (or gives up after MAX_ATTEMPTS)."""
    log = _log.bind(
        job_id=str(job.id),
        item_id=str(job.item_id),
        user_id=str(job.user_id),
        kind=job.kind,
        attempt=job.attempts,
    )
    item = db.get(WardrobeItem, job.item_id)
    if item is None:  # deleted while queued (the job cascades too)
        _finish(db, job, "done")
        return
    try:
        if job.kind == "mannequin":
            await _mannequin(db, job, item, storage, garment_images)
        else:
            await _cutout(db, job, item, storage, garment_images, remover)
    except JobFailed as e:
        db.rollback()
        _retry_or_give_up(db, job, str(e), log)
        return
    except Exception as e:  # noqa: BLE001 — anything else: retried too
        db.rollback()
        _retry_or_give_up(db, job, f"{type(e).__name__}: {e}", log)
        return
    _finish(db, job, "done")
    log.info("image_job.done")


async def _mannequin(
    db: Session,
    job: ImageJob,
    item: WardrobeItem,
    storage: ImageStorageProvider,
    garment_images: GarmentImageProvider,
) -> None:
    from app.services.wardrobe_service import MAX_IMAGES_PER_ITEM

    images = list(item.images or [])
    if job.source_url not in images or len(images) >= MAX_IMAGES_PER_ITEM:
        return  # the photo was removed, or the item filled up meanwhile
    photo, media_type = _read(storage, job.source_url)
    try:
        shot = await garment_images.generate(
            photo, media_type=media_type, prompt=GHOST_MANNEQUIN_PROMPT
        )
    except GarmentImageError as e:
        raise JobFailed(f"{e.code}: {e}") from e
    url = storage.upload(
        content=shot.content,
        content_type=shot.content_type,
        key_hint=f"wardrobe/{item.user_id}/{item.id}",
    )
    # Just before its photo; a first photo's shot becomes the item's picture.
    images = list(item.images or [])
    images.insert(images.index(job.source_url), url)
    item.images = images
    if item.primary_image_url in (None, job.source_url):
        item.primary_image_url = url
    db.commit()


async def _cutout(
    db: Session,
    job: ImageJob,
    item: WardrobeItem,
    storage: ImageStorageProvider,
    garment_images: GarmentImageProvider,
    remover: BackgroundRemover,
) -> None:
    from app.services.wardrobe_service import save_cutout

    if item.cutout_url:
        return
    photo, media_type = _read(storage, job.source_url)
    cut = await cutout_service.make_cutout(
        photo,
        media_type=media_type,
        color_hex=item.color_hex,
        category=item.category,
        garment_images=garment_images,
        remover=remover,
    )
    if cut is None:  # the reason is logged by cutout_service
        raise JobFailed("no cut-out (see cutout.* log)")
    save_cutout(db, item=item, cut=cut, storage=storage)


def _read(storage: ImageStorageProvider, url: str) -> tuple[bytes, str]:
    stored = storage.read(url=url)
    if stored is None:
        raise JobFailed("source photo not found")
    content, media_type = stored
    if media_type == "application/octet-stream":
        # Let Pillow name it (the image model wants a real image type).
        try:
            with Image.open(io.BytesIO(content)) as im:
                media_type = Image.MIME.get(im.format or "", "image/jpeg")
        except OSError as e:
            raise JobFailed("source photo unreadable") from e
    return content, media_type


def _finish(db: Session, job: ImageJob, status: JobStatus) -> None:
    job.status = status
    db.commit()


def _retry_or_give_up(db: Session, job: ImageJob, error: str, log) -> None:
    job.last_error = error[:300]
    if job.attempts >= MAX_ATTEMPTS:
        job.status = "failed"
        db.commit()
        log.warning("image_job.failed", error=error)
        return
    wait = RETRY_WAITS[job.attempts - 1]
    job.status = "pending"
    job.next_attempt_at = _now() + wait
    db.commit()
    log.info("image_job.retry", error=error, wait_s=int(wait.total_seconds()))
