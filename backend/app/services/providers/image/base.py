from __future__ import annotations

from abc import ABC, abstractmethod


class ImageStorageProvider(ABC):
    """Stores wardrobe / avatar / outfit images.

    Phase 5c: interface only — no route currently uploads. Phase 5e wires the
    real S3 impl behind /wardrobe/items image attachment + batch-upload.
    """

    @abstractmethod
    def upload(self, *, content: bytes, content_type: str, key_hint: str) -> str:
        """Persist `content` and return a stable, fetchable URL."""

    @abstractmethod
    def delete(self, *, url: str) -> None:
        """Idempotent — no-op if the URL is unknown."""
