from __future__ import annotations

from app.services.providers.image.base import ImageStorageProvider


class S3ImageStorage(ImageStorageProvider):
    """Tbd/prd S3-backed storage. Wired in Phase 5e."""

    def __init__(self, *, bucket: str, region: str) -> None:
        self._bucket = bucket
        self._region = region

    def upload(self, *, content: bytes, content_type: str, key_hint: str) -> str:
        raise NotImplementedError("S3 upload lands in Phase 5e")

    def delete(self, *, url: str) -> None:
        raise NotImplementedError("S3 delete lands in Phase 5e")
