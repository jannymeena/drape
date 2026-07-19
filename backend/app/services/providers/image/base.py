from __future__ import annotations

from abc import ABC, abstractmethod
from datetime import datetime
from typing import Iterator


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
    def delete(self, *, url: str) -> None:
        """Idempotent — no-op if the URL is unknown."""

    @abstractmethod
    def list_all(self) -> Iterator[tuple[str, datetime]]:
        """Yield (url, last_modified_utc) for every stored object.

        Powers the orphaned-image GC (scripts/gc_orphaned_images.py): URLs are
        compared against DB references, so they must be in exactly the form
        `upload()` returned them."""
