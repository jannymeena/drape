from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Literal

# PNG is lossless (the cut-out keys out the backdrop the model draws);
# JPG is far smaller, for shots shown as they are.
OutputFormat = Literal["png", "jpg"]


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
        self,
        image_bytes: bytes,
        *,
        media_type: str,
        prompt: str,
        output_format: OutputFormat = "png",
        transparent: bool = False,
        size: tuple[int, int] | None = None,
    ) -> GeneratedImage:
        """Returns the generated image in [output_format] — with a
        transparent background when [transparent] (PNG only), [size] (width,
        height) pixels when given, else the provider's own pick — or raises
        GarmentImageError."""
