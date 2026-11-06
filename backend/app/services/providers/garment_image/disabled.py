from __future__ import annotations

from app.services.providers.garment_image.base import (
    GarmentImageError,
    GarmentImageProvider,
    GeneratedImage,
)


class DisabledGarmentImageProvider(GarmentImageProvider):
    """No image model configured (no GOOGLE_AI_API_KEY): uploads keep just
    the user's photo."""

    enabled = False

    async def generate(
        self, image_bytes: bytes, *, media_type: str, prompt: str
    ) -> GeneratedImage:
        raise GarmentImageError("disabled", "No garment image model is configured")
