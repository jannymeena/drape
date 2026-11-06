from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


class GarmentImageError(Exception):
    """The image model couldn't produce an image (call failed, refused, or
    answered with no image). Callers keep the original photo."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class GeneratedImage:
    content: bytes
    content_type: str


class GarmentImageProvider(ABC):
    """Turns a garment photo into a new image from a prompt (e.g. the garment
    on a ghost mannequin)."""

    # False for the no-op stand-in: the caller then skips the work entirely.
    enabled: bool = True

    @abstractmethod
    async def generate(
        self, image_bytes: bytes, *, media_type: str, prompt: str
    ) -> GeneratedImage:
        """Returns the generated image, or raises GarmentImageError."""
