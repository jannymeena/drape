from __future__ import annotations

import io
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Iterator

from PIL import Image


def image_dimensions(content: bytes) -> tuple[int | None, int | None]:
    """(width, height) in pixels, read from the image's header only — or
    (None, None) if it isn't an image Pillow can read. For logging; never
    raises."""
    try:
        with Image.open(io.BytesIO(content)) as im:
            return im.size
    except Exception:  # noqa: BLE001 — unreadable: just no dimensions
        return None, None


class ImageStorageProvider(ABC):
    """Stores wardrobe / avatar / outfit images.

    Dev: `LocalFsStorage` (writes to ./uploads, served via StaticFiles).
    Tbd/prd: `S3ImageStorage` (boto3 PUT, optional CloudFront URL).
    Wired in Phase 5e behind `POST /wardrobe/items/{id}/images`.
    """

    @abstractmethod
    def upload(self, *, content: bytes, content_type: str, key_hint: str) -> str:
        """Persist `content` and return a stable, fetchable URL."""

    @abstractmethod
    def read(self, *, url: str) -> tuple[bytes, str] | None:
        """The stored bytes and content type at `url` (one `upload()`
        returned), or None if it isn't there. The background image jobs
        read the user's photo back with it."""

    @abstractmethod
    def delete(self, *, url: str) -> None:
        """Idempotent — no-op if the URL is unknown."""

    @abstractmethod
    def list_all(self) -> Iterator[tuple[str, datetime]]:
        """Yield (url, last_modified_utc) for every stored object.

        Powers the orphaned-image GC (scripts/gc_orphaned_images.py): URLs are
        compared against DB references, so they must be in exactly the form
        `upload()` returned them."""
