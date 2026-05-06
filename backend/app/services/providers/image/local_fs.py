from __future__ import annotations

import hashlib
from pathlib import Path

import structlog

from app.services.providers.image.base import ImageStorageProvider

_log = structlog.get_logger("provider.image.local_fs")


class LocalFsStorage(ImageStorageProvider):
    """Dev impl: writes bytes to disk and serves them through FastAPI's
    StaticFiles mount at `base_url`.

    The S3 impl is the source of truth for tbd/prd; this exists so that dev
    can render uploaded images in a browser without touching AWS.
    """

    _EXT = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
    }

    def __init__(self, *, root: Path, base_url: str) -> None:
        self._root = root
        self._base_url = base_url.rstrip("/")
        self._root.mkdir(parents=True, exist_ok=True)

    def upload(self, *, content: bytes, content_type: str, key_hint: str) -> str:
        ext = self._EXT.get(content_type, "")
        digest = hashlib.sha256(content).hexdigest()[:16]
        filename = f"{key_hint}-{digest}{ext}"
        path = self._root / filename
        if not path.exists():
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
        _log.info(
            "image.uploaded",
            backend="local_fs",
            filename=filename,
            bytes=len(content),
            content_type=content_type,
        )
        return f"{self._base_url}/{filename}"

    def delete(self, *, url: str) -> None:
        if not url.startswith(self._base_url + "/"):
            return None
        filename = url[len(self._base_url) + 1 :]
        path = self._root / filename
        try:
            path.unlink()
        except FileNotFoundError:
            return None
        _log.info("image.deleted", backend="local_fs", filename=filename)
