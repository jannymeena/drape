"""Wardrobe photos: stored on upload; a ghost-mannequin shot of each and the
item's folded cut-out made in the background (image_job_service), retried
when they fail.

The image provider is faked here; the Gemini REST layer has its own tests in
tests/services/test_garment_image_gemini.py.
"""

from __future__ import annotations

import io
from datetime import datetime, timedelta, timezone

import pytest
import structlog.testing
from PIL import Image, ImageDraw
from sqlalchemy import select

from app.db.models import ImageJob
from app.services import image_job_service
from app.services.cutout_service import CANVAS, FOLDED_PROMPT
from app.services.image_job_service import GHOST_MANNEQUIN_PROMPT, MAX_ATTEMPTS
from app.services.providers.background_removal.chroma_key import ChromaKeyRemover
from app.services.providers.garment_image.base import (
    GarmentImageError,
    GarmentImageProvider,
    GeneratedImage,
)
from tests.factories import make_outfit, make_wardrobe_item


def _png(colour=(200, 200, 200)) -> bytes:
    out = io.BytesIO()
    Image.new("RGB", (8, 8), colour).save(out, format="PNG")
    return out.getvalue()


_PHOTO = _png()
_MANNEQUIN = _png((10, 10, 10))


def _folded_on_magenta() -> bytes:
    img = Image.new("RGB", (400, 400), (255, 0, 255))
    ImageDraw.Draw(img).rectangle([100, 120, 300, 280], fill=(20, 30, 80))
    out = io.BytesIO()
    img.save(out, format="PNG")
    return out.getvalue()


class _FakeGarmentImages(GarmentImageProvider):
    """A mannequin shot for the mannequin prompt; a folded piece on magenta
    for the cut-out prompt. [fail] = how many calls fail before it works."""

    def __init__(self) -> None:
        self.calls: list[tuple[bytes, str, str]] = []
        self.fail = 0

    async def generate(
        self, image_bytes: bytes, *, media_type: str, prompt: str
    ) -> GeneratedImage:
        self.calls.append((image_bytes, media_type, prompt))
        if self.fail > 0:
            self.fail -= 1
            raise GarmentImageError("call_failed", "Gemini image call returned 429")
        if prompt.startswith(FOLDED_PROMPT):
            return GeneratedImage(content=_folded_on_magenta(), content_type="image/png")
        return GeneratedImage(content=_MANNEQUIN, content_type="image/png")

    def prompts(self, start: str) -> list[str]:
        return [p for _, _, p in self.calls if p.startswith(start)]


@pytest.fixture
def garment_images() -> _FakeGarmentImages:
    # Replaces conftest's disabled provider for this module's client.
    return _FakeGarmentImages()


def _upload(client, item_id, count: int = 1):
    return client.post(
        f"/api/v1/wardrobe/items/{item_id}/images",
        files=[("files", (f"p{i}.png", _PHOTO, "image/png")) for i in range(count)],
    )


def _stored(image_storage, url: str) -> bytes:
    return (image_storage._root / url.split("/images/", 1)[1]).read_bytes()


async def _work(db, image_storage, garment_images) -> int:
    """What the image worker does: every due job, one at a time."""
    worked = 0
    while (job := image_job_service.claim_next(db)) is not None:
        await image_job_service.process(
            db,
            job,
            storage=image_storage,
            garment_images=garment_images,
            remover=ChromaKeyRemover(),
        )
        worked += 1
    return worked


def _jobs(db, item_id) -> list[ImageJob]:
    db.expire_all()
    return list(
        db.scalars(
            select(ImageJob)
            .where(ImageJob.item_id == item_id)
            .order_by(ImageJob.created_at, ImageJob.kind)
        ).all()
    )


def _make_due(db, item_id) -> None:
    for job in _jobs(db, item_id):
        job.next_attempt_at = datetime.now(timezone.utc) - timedelta(seconds=1)
    db.commit()


def test_the_upload_returns_without_waiting_for_images(
    authed_client, db, garment_images
):
    item = make_wardrobe_item(db, authed_client.test_user)
    r = _upload(authed_client, item.id)

    assert r.status_code == 200, r.text
    body = r.json()
    # Just the photo for now; nothing asked of the image model yet.
    assert len(body["images"]) == 1 and body["cutout_url"] is None
    assert garment_images.calls == []
    # Queued: its mannequin shot and the item's cut-out.
    assert sorted(j.kind for j in _jobs(db, item.id)) == ["cutout", "mannequin"]


async def test_the_worker_puts_the_mannequin_shot_first(
    authed_client, db, garment_images, image_storage
):
    item = make_wardrobe_item(db, authed_client.test_user)
    photo_url = _upload(authed_client, item.id).json()["images"][0]

    assert await _work(db, image_storage, garment_images) == 2

    db.refresh(item)
    # The shot, then the photo; the shot is the item's picture.
    assert len(item.images) == 2 and item.images[1] == photo_url
    assert item.primary_image_url == item.images[0]
    assert _stored(image_storage, item.images[0]) == _MANNEQUIN
    assert garment_images.prompts(GHOST_MANNEQUIN_PROMPT) == [GHOST_MANNEQUIN_PROMPT]
    assert all(j.status == "done" for j in _jobs(db, item.id))


async def test_the_worker_makes_the_cut_out(
    authed_client, db, garment_images, image_storage
):
    item = make_wardrobe_item(db, authed_client.test_user)
    _upload(authed_client, item.id, count=2)
    await _work(db, image_storage, garment_images)

    body = authed_client.get(f"/api/v1/wardrobe/items/{item.id}").json()
    # Made once, from the first photo; kept out of the photos.
    folded = [c for c in garment_images.calls if c[2].startswith(FOLDED_PROMPT)]
    assert len(folded) == 1 and folded[0][0] == _PHOTO
    assert body["cutout_url"] and body["cutout_url"] not in body["images"]
    img = Image.open(io.BytesIO(_stored(image_storage, body["cutout_url"])))
    assert img.format == "WEBP" and img.size == (CANVAS, CANVAS)
    assert img.mode == "RGBA"
    x, y, w, h = body["cutout_box"]
    assert 0 < x < 0.5 and 0 < y < 0.5 and w > 0.5 and h > 0.3


async def test_a_failed_try_is_retried_later(
    authed_client, db, garment_images, image_storage
):
    item = make_wardrobe_item(db, authed_client.test_user)
    _upload(authed_client, item.id)
    garment_images.fail = 2  # both jobs' first tries

    await _work(db, image_storage, garment_images)
    jobs = _jobs(db, item.id)
    assert all(j.status == "pending" and j.attempts == 1 for j in jobs)
    assert all(j.next_attempt_at > datetime.now(timezone.utc) for j in jobs)
    errors = {j.kind: j.last_error or "" for j in jobs}
    assert "429" in errors["mannequin"] and errors["cutout"]
    # Not due yet: nothing happens.
    assert await _work(db, image_storage, garment_images) == 0

    _make_due(db, item.id)
    await _work(db, image_storage, garment_images)
    db.refresh(item)
    assert item.cutout_url and len(item.images) == 2
    assert all(j.status == "done" for j in _jobs(db, item.id))


async def test_a_job_that_keeps_failing_is_given_up_and_logged(
    authed_client, db, garment_images, image_storage
):
    item = make_wardrobe_item(db, authed_client.test_user)
    _upload(authed_client, item.id)
    garment_images.fail = 99

    with structlog.testing.capture_logs() as logs:
        for _ in range(MAX_ATTEMPTS):
            await _work(db, image_storage, garment_images)
            _make_due(db, item.id)

    jobs = _jobs(db, item.id)
    assert all(j.status == "failed" and j.attempts == MAX_ATTEMPTS for j in jobs)
    failed = [e for e in logs if e["event"] == "image_job.failed"]
    assert {e["kind"] for e in failed} == {"mannequin", "cutout"}
    assert all(e["item_id"] == str(item.id) for e in failed)
    db.refresh(item)
    assert len(item.images) == 1 and item.cutout_url is None  # the photo stays


async def test_a_job_left_running_by_a_restart_goes_back_in_the_queue(
    authed_client, db, garment_images, image_storage
):
    item = make_wardrobe_item(db, authed_client.test_user)
    _upload(authed_client, item.id)
    image_job_service.claim_next(db)  # …and the process stops here

    assert image_job_service.requeue_stale(db) == 1
    assert await _work(db, image_storage, garment_images) == 2


def test_shots_only_while_there_is_room(authed_client, db, garment_images):
    item = make_wardrobe_item(db, authed_client.test_user)
    # 3 photos into an empty item (cap 4): room for one shot only.
    r = _upload(authed_client, item.id, count=3)

    assert r.status_code == 200, r.text
    kinds = [j.kind for j in _jobs(db, item.id)]
    assert kinds.count("mannequin") == 1 and kinds.count("cutout") == 1

    # The queued shot counts: a 4th photo fits, but no shot for it.
    assert _upload(authed_client, item.id).status_code == 200
    assert [j.kind for j in _jobs(db, item.id)].count("mannequin") == 1

    # Full: refused.
    assert _upload(authed_client, item.id).status_code == 400


def test_one_cut_out_per_item(authed_client, db, garment_images):
    item = make_wardrobe_item(db, authed_client.test_user)
    _upload(authed_client, item.id)
    _upload(authed_client, item.id)

    assert [j.kind for j in _jobs(db, item.id)].count("cutout") == 1


def test_no_image_model_no_jobs(authed_client, db, garment_images):
    garment_images.enabled = False  # no GOOGLE_AI_API_KEY
    item = make_wardrobe_item(db, authed_client.test_user)
    assert _upload(authed_client, item.id).status_code == 200
    assert _jobs(db, item.id) == []


def test_someone_elses_item_queues_nothing(
    authed_client, db, garment_images, make_user
):
    other = make_user(email="other@example.com")
    item = make_wardrobe_item(db, other)
    r = _upload(authed_client, item.id)

    assert r.status_code == 404
    assert _jobs(db, item.id) == []


async def test_a_deleted_item_drops_its_jobs(authed_client, db, garment_images):
    item = make_wardrobe_item(db, authed_client.test_user)
    _upload(authed_client, item.id)
    assert authed_client.delete(f"/api/v1/wardrobe/items/{item.id}").status_code == 204

    assert _jobs(db, item.id) == []
    assert garment_images.calls == []


def test_items_carry_their_dress_priority(authed_client, db):
    item = make_wardrobe_item(db, authed_client.test_user, category="outerwear")
    r = authed_client.get(f"/api/v1/wardrobe/items/{item.id}")

    assert r.status_code == 200, r.text
    assert r.json()["dress_priority"] == 900


async def test_a_new_cut_out_reaches_outfits_already_made(
    authed_client, db, garment_images, image_storage
):
    # The outfit was made before the shirt had a cut-out.
    shirt = make_wardrobe_item(db, authed_client.test_user, name="Shirt")
    jeans = make_wardrobe_item(db, authed_client.test_user, category="bottoms")
    outfit = make_outfit(db, authed_client.test_user, items=[shirt, jeans])

    _upload(authed_client, shirt.id)
    await _work(db, image_storage, garment_images)

    db.refresh(shirt)
    db.refresh(outfit)
    pieces = {p["item_id"]: p for p in outfit.items}
    assert pieces[str(shirt.id)]["cutout_url"] == shirt.cutout_url
    assert pieces[str(shirt.id)]["cutout_box"] == shirt.cutout_box
    assert pieces[str(jeans.id)].get("cutout_url") is None
