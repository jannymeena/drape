from __future__ import annotations

import asyncio
import base64
import time

import httpx
import structlog

from app.services.providers.garment_image.base import (
    GarmentImageError,
    GarmentImageProvider,
    GeneratedImage,
)

_log = structlog.get_logger("garment_image.gemini")

# Where a key works depends on where it was made: an AI Studio key calls the
# Gemini API; a Google Cloud "Agent Platform" (Vertex AI) key calls Agent
# Platform. Same request and reply either way.
ENDPOINTS = {
    "gemini_api": "https://generativelanguage.googleapis.com/v1beta/models",
    "agent_platform": "https://aiplatform.googleapis.com/v1/publishers/google/models",
}
# Image generation is slow next to a text call, and the upload waits on it:
# at most two calls per upload, inside the app's 2-minute wait for it.
_TIMEOUT_S = 45.0

# Google's per-minute quota answers 429 when uploads come in quick
# succession (a batch of items, two images each). Wait and try again: these
# waits, or Google's own Retry-After when it sends one (capped at the same).
_RETRY_WAITS_S = (5.0, 15.0, 30.0)


class GeminiGarmentImageProvider(GarmentImageProvider):
    """Google's Gemini image models ("Nano Banana") over REST, on the Gemini
    API or Agent Platform ([ENDPOINTS]): the photo and the prompt in, an
    image part out."""

    def __init__(
        self, api_key: str, *, model: str, endpoint: str = "agent_platform"
    ) -> None:
        self._api_key = api_key
        self.model = model
        self._base_url = ENDPOINTS[endpoint]

    # Overridable in tests.
    retry_waits: tuple[float, ...] = _RETRY_WAITS_S

    async def _sleep(self, seconds: float) -> None:
        await asyncio.sleep(seconds)

    async def generate(
        self, image_bytes: bytes, *, media_type: str, prompt: str
    ) -> GeneratedImage:
        body = {
            "contents": [
                {
                    # Agent Platform requires the role; the Gemini API allows it.
                    "role": "user",
                    "parts": [
                        {"text": prompt},
                        {
                            "inline_data": {
                                "mime_type": media_type,
                                "data": base64.b64encode(image_bytes).decode(),
                            }
                        },
                    ]
                }
            ],
            "generationConfig": {"responseModalities": ["IMAGE"]},
        }
        started = time.monotonic()
        waits = list(self.retry_waits)
        while True:
            try:
                async with httpx.AsyncClient(timeout=_TIMEOUT_S) as client:
                    resp = await client.post(
                        f"{self._base_url}/{self.model}:generateContent",
                        # The key goes in a header, never the URL (URLs get logged).
                        headers={"x-goog-api-key": self._api_key},
                        json=body,
                    )
            except httpx.HTTPError as exc:
                raise GarmentImageError(
                    "call_failed", f"Gemini image call failed: {type(exc).__name__}"
                ) from exc
            if resp.status_code != 429 or not waits:
                break
            wait = _retry_after(resp, cap=waits[-1]) or waits[0]
            waits.pop(0)
            _log.info("garment_image.rate_limited", model=self.model, wait_s=wait)
            await self._sleep(wait)
        latency_ms = int((time.monotonic() - started) * 1000)
        if resp.status_code != 200:
            # Google's error body names the problem (bad key, quota, model)
            # and never echoes the key.
            raise GarmentImageError(
                "call_failed",
                f"Gemini image call returned {resp.status_code}: {resp.text[:300]}",
            )
        image = _first_image(resp.json())
        if image is None:
            raise GarmentImageError(
                "no_image", "Gemini answered without an image (refused or blocked)"
            )
        _log.info(
            "garment_image.generated",
            model=self.model,
            latency_ms=latency_ms,
            size_bytes=len(image.content),
        )
        return image


def _retry_after(resp: httpx.Response, *, cap: float) -> float | None:
    """Google's Retry-After (seconds), if it sent a usable one, capped."""
    try:
        value = float(resp.headers.get("retry-after", ""))
    except ValueError:
        return None
    return min(value, cap) if value > 0 else None


def _first_image(payload: dict) -> GeneratedImage | None:
    for candidate in payload.get("candidates") or []:
        for part in (candidate.get("content") or {}).get("parts") or []:
            # The REST API answers in camelCase; accept snake_case too.
            data = part.get("inlineData") or part.get("inline_data")
            if data and data.get("data"):
                return GeneratedImage(
                    content=base64.b64decode(data["data"]),
                    content_type=data.get("mimeType")
                    or data.get("mime_type")
                    or "image/png",
                )
    return None
