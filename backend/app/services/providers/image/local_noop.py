from __future__ import annotations

import hashlib

from app.services.providers.image.base import ImageStorageProvider


class LocalNoopImageStorage(ImageStorageProvider):
    """Dev-only: returns a deterministic fake URL without actually storing bytes.

    Lets routes that need a URL run end-to-end in dev without depending on S3
    or local disk. Phase 5e replaces the prod path with S3ImageStorage.
    """

    _BASE = "https://dev.drape.local/img"

    def upload(self, *, content: bytes, content_type: str, key_hint: str) -> str:
        digest = hashlib.sha256(content).hexdigest()[:16]
        ext = self._ext_for(content_type)
        return f"{self._BASE}/{key_hint}-{digest}{ext}"

    def delete(self, *, url: str) -> None:
        return None

    @staticmethod
    def _ext_for(content_type: str) -> str:
        return {
            "image/jpeg": ".jpg",
            "image/png": ".png",
            "image/webp": ".webp",
        }.get(content_type, "")
