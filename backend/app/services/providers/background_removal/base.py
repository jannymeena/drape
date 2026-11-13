from __future__ import annotations

from abc import ABC, abstractmethod

from PIL import Image


class BackgroundRemovalError(Exception):
    """The background couldn't be separated from the piece (uneven backdrop,
    nothing left, or everything left). The caller goes without a cut-out."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


class BackgroundRemover(ABC):
    """Turns an image of one piece on a plain backdrop into the piece alone,
    on transparency."""

    @abstractmethod
    def remove(
        self, image: Image.Image, *, backdrop: tuple[int, int, int]
    ) -> Image.Image:
        """Returns an RGBA image the size of [image], or raises
        BackgroundRemovalError. [backdrop] is the colour the backdrop was
        asked to be; an implementation may refine it from the image."""
