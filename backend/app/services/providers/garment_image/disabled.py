from __future__ import annotations

from app.services.providers.garment_image.base import (
    GarmentImageError,
    GarmentImageProvider,
    GeneratedImage,
    OutputFormat,
)


class DisabledGarmentImageProvider(GarmentImageProvider):
    """No image model configured (no RUNWARE_API_KEY): uploads keep just
    the user's photo."""

    enabled = False

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
        raise GarmentImageError("disabled", "No garment image model is configured")
