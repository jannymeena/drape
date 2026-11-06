"""Wardrobe photos also shown on a ghost mannequin (garment image provider).

The provider is faked here; the Gemini REST layer has its own tests in
tests/services/test_garment_image_gemini.py.
"""

from __future__ import annotations

import pytest

from app.services.providers.garment_image.base import (
    GarmentImageError,
    GarmentImageProvider,
    GeneratedImage,
)
from app.services.wardrobe_service import GHOST_MANNEQUIN_PROMPT
from tests.factories import make_wardrobe_item

_TINY_PNG = (
    b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
    b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\rIDATx\x9cc\xf8\xff\xff?"
    b"\x00\x05\xfe\x02\xfe\xa7V\xbd\xfa\x00\x00\x00\x00IEND\xaeB`\x82"
)
_MANNEQUIN = b"mannequin-shot"


class _FakeGarmentImages(GarmentImageProvider):
    def __init__(self) -> None:
        self.calls: list[tuple[bytes, str, str]] = []
        self.fail = False

    async def generate(
        self, image_bytes: bytes, *, media_type: str, prompt: str
    ) -> GeneratedImage:
        self.calls.append((image_bytes, media_type, prompt))
        if self.fail:
            raise GarmentImageError("no_image", "refused")
        return GeneratedImage(content=_MANNEQUIN, content_type="image/png")


@pytest.fixture
def garment_images() -> _FakeGarmentImages:
    # Replaces conftest's disabled provider for this module's client.
    return _FakeGarmentImages()


def _upload(client, item_id, count: int = 1):
    return client.post(
        f"/api/v1/wardrobe/items/{item_id}/images",
        files=[("files", (f"p{i}.png", _TINY_PNG, "image/png")) for i in range(count)],
    )


def _stored(image_storage, url: str) -> bytes:
    return (image_storage._root / url.split("/images/", 1)[1]).read_bytes()


def test_the_photo_is_shown_on_a_mannequin_first(
    authed_client, db, garment_images, image_storage
):
    item = make_wardrobe_item(db, authed_client.test_user)
    r = _upload(authed_client, item.id)

    assert r.status_code == 200, r.text
    body = r.json()
    # The mannequin shot, then the photo; the shot is the item's picture.
    assert len(body["images"]) == 2
    assert body["primary_image_url"] == body["images"][0]
    assert _stored(image_storage, body["images"][0]) == _MANNEQUIN
    assert _stored(image_storage, body["images"][1]) == _TINY_PNG
    assert garment_images.calls == [(_TINY_PNG, "image/png", GHOST_MANNEQUIN_PROMPT)]


def test_a_failed_shot_keeps_the_photo(authed_client, db, garment_images):
    garment_images.fail = True
    item = make_wardrobe_item(db, authed_client.test_user)
    r = _upload(authed_client, item.id)

    assert r.status_code == 200, r.text
    assert len(r.json()["images"]) == 1


def test_shots_only_while_there_is_room(authed_client, db, garment_images):
    item = make_wardrobe_item(db, authed_client.test_user)
    # 3 photos into an empty item (cap 4): room for one shot only.
    r = _upload(authed_client, item.id, count=3)

    assert r.status_code == 200, r.text
    assert len(r.json()["images"]) == 4
    assert len(garment_images.calls) == 1

    # Full: a photo that doesn't fit is refused before Google is asked.
    r = _upload(authed_client, item.id)
    assert r.status_code == 400
    assert len(garment_images.calls) == 1


def test_someone_elses_item_never_reaches_google(
    authed_client, db, garment_images, make_user
):
    other = make_user(email="other@example.com")
    item = make_wardrobe_item(db, other)
    r = _upload(authed_client, item.id)

    assert r.status_code == 404
    assert garment_images.calls == []
