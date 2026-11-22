from __future__ import annotations

import asyncio
import base64
import io
import math
import time
import uuid

import httpx
import structlog
from PIL import Image

from app.services.providers.garment_image.base import (
    GarmentImageError,
    GarmentImageProvider,
    GeneratedImage,
    OutputFormat,
)

_log = structlog.get_logger("garment_image.runware")

API_URL = "https://api.runware.ai/v1"

# Runware holds a sync request up to 120 s before answering "still
# processing"; wait a little past that. The image job runs in the
# background, so the upload never waits on this.
_TIMEOUT_S = 130.0

# 429 = the model's queue or our org limit is full; 503 = a passing capacity
# squeeze. Both are safe to resend: these waits, or Runware's own
# Retry-After / retryAfter when it sends one (capped at the same).
_RETRY_STATUSES = {429, 503}
_RETRY_WAITS_S = (5.0, 15.0, 30.0)

# Output size. Runware wants both sides set: multiples of 16, 0.66–8.29 MP,
# aspect between 1:3 and 3:1. About 1 MP, shaped like the photo, keeps the
# cost down and is plenty for a wardrobe tile.
_TARGET_PIXELS = 1024 * 1024
_STEP = 16
_MAX_ASPECT = 3.0
_SQUARE = (1024, 1024)

# Our format name -> Runware's outputFormat and the stored content type.
_FORMATS: dict[str, tuple[str, str]] = {
    "png": ("PNG", "image/png"),
    "jpg": ("JPG", "image/jpeg"),
}


class RunwareGarmentImageProvider(GarmentImageProvider):
    """An image model on Runware (default OpenAI GPT-Image-2.6 Flare) over
    REST: the photo as the reference image and the prompt in, one image out
    (PNG or JPG)."""

    def __init__(self, api_key: str, *, model: str) -> None:
        self._api_key = api_key
        self.model = model

    # Overridable in tests.
    retry_waits: tuple[float, ...] = _RETRY_WAITS_S

    async def _sleep(self, seconds: float) -> None:
        await asyncio.sleep(seconds)

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
        if transparent and output_format != "png":
            # Runware allows a transparent background only in PNG/WEBP.
            raise ValueError("A transparent background needs PNG output")
        if size is not None:
            _check_size(*size)
        runware_format, content_type = _FORMATS[output_format]
        width, height = size or output_size(image_bytes)
        task_uuid = str(uuid.uuid4())
        body = [
            {
                "taskType": "imageInference",
                "taskUUID": task_uuid,
                "model": self.model,
                "positivePrompt": prompt,
                "inputs": {
                    "referenceImages": [
                        f"data:{media_type};base64,"
                        + base64.b64encode(image_bytes).decode()
                    ]
                },
                "width": width,
                "height": height,
                "numberResults": 1,
                "outputType": "base64Data",
                "outputFormat": runware_format,
                # Said either way: left on "auto", the model may make a
                # backdrop transparent that the cut-out needs drawn.
                "settings": {
                    "background": "transparent" if transparent else "opaque"
                },
            }
        ]
        started = time.monotonic()
        waits = list(self.retry_waits)
        async with httpx.AsyncClient(timeout=_TIMEOUT_S) as client:
            while True:
                try:
                    resp = await client.post(
                        API_URL,
                        # The key goes in a header, never the URL or body logs.
                        headers={"Authorization": f"Bearer {self._api_key}"},
                        json=body,
                    )
                except httpx.HTTPError as exc:
                    raise GarmentImageError(
                        "call_failed",
                        f"Runware image call failed: {type(exc).__name__}",
                    ) from exc
                if resp.status_code not in _RETRY_STATUSES or not waits:
                    break
                wait = _retry_after(resp, cap=waits[-1]) or waits[0]
                waits.pop(0)
                _log.info(
                    "garment_image.rate_limited",
                    model=self.model,
                    status=resp.status_code,
                    wait_s=wait,
                )
                await self._sleep(wait)

            latency_ms = int((time.monotonic() - started) * 1000)
            payload = _json(resp)
            if resp.status_code != 200 or payload.get("errors"):
                raise GarmentImageError(
                    "call_failed",
                    f"Runware image call returned {resp.status_code}: "
                    f"{_error_text(payload, resp)}",
                )
            result = _result(payload, task_uuid)
            if result is not None and result.get("status") == "processing":
                # Still drawing after Runware's sync window. Rare for Flare;
                # the image job tries again later.
                raise GarmentImageError(
                    "call_failed", "Runware image call still processing after 120 s"
                )
            content = await _image_bytes(client, result)
        if content is None:
            raise GarmentImageError(
                "no_image", "Runware answered without an image (refused or blocked)"
            )
        _log.info(
            "garment_image.generated",
            model=self.model,
            width=width,
            height=height,
            output_format=output_format,
            transparent=transparent,
            latency_ms=latency_ms,
            size_bytes=len(content),
            cost=(result or {}).get("cost"),
        )
        return GeneratedImage(content=content, content_type=content_type)


def output_size(image_bytes: bytes) -> tuple[int, int]:
    """About 1 MP in the photo's shape (aspect clamped to 1:3–3:1), both
    sides multiples of 16; square when the photo can't be read."""
    try:
        with Image.open(io.BytesIO(image_bytes)) as im:
            w, h = im.size
    except Exception:  # noqa: BLE001 — any unreadable photo just gets a square
        return _SQUARE
    if not w or not h:
        return _SQUARE
    aspect = min(max(w / h, 1 / _MAX_ASPECT), _MAX_ASPECT)
    height = math.sqrt(_TARGET_PIXELS / aspect)
    width = height * aspect
    return _snap(width), _snap(height)


def _check_size(width: int, height: int) -> None:
    """Runware's limits on a requested size: sides multiples of 16, at most
    3840; 0.66–8.29 MP; aspect between 1:3 and 3:1."""
    ok = (
        width % _STEP == 0
        and height % _STEP == 0
        and 0 < width <= 3840
        and 0 < height <= 3840
        and 0.66e6 <= width * height <= 8.29e6
        and 1 / _MAX_ASPECT <= width / height <= _MAX_ASPECT
    )
    if not ok:
        raise ValueError(f"Runware can't make a {width}x{height} image")


def _snap(side: float) -> int:
    return max(_STEP, int(round(side / _STEP)) * _STEP)


def _json(resp: httpx.Response) -> dict:
    try:
        payload = resp.json()
    except ValueError:
        return {}
    return payload if isinstance(payload, dict) else {}


def _error_text(payload: dict, resp: httpx.Response) -> str:
    """Runware's own error message(s) — they never echo the key."""
    errors = payload.get("errors") or []
    messages = [
        str(e.get("message") or e.get("code"))
        for e in errors
        if isinstance(e, dict) and (e.get("message") or e.get("code"))
    ]
    return "; ".join(messages)[:300] if messages else resp.text[:300]


def _retry_after(resp: httpx.Response, *, cap: float) -> float | None:
    """Runware's wait (Retry-After header, or retryAfter in the error body),
    if it sent a usable one, capped."""
    candidates: list[object] = [resp.headers.get("retry-after")]
    for e in _json(resp).get("errors") or []:
        if isinstance(e, dict):
            candidates.append(e.get("retryAfter"))
    for value in candidates:
        try:
            seconds = float(value)  # type: ignore[arg-type]
        except (TypeError, ValueError):
            continue
        if seconds > 0:
            return min(seconds, cap)
    return None


def _result(payload: dict, task_uuid: str) -> dict | None:
    """This task's entry in `data` (the only one, as we send one task)."""
    items = [d for d in payload.get("data") or [] if isinstance(d, dict)]
    for item in items:
        if item.get("taskUUID") == task_uuid:
            return item
    return items[0] if items else None


async def _image_bytes(client: httpx.AsyncClient, result: dict | None) -> bytes | None:
    """The image from a result: base64 (asked for), a data URI, or — as a
    fallback — the hosted URL."""
    if not result:
        return None
    b64 = result.get("imageBase64Data")
    if b64:
        return base64.b64decode(b64)
    data_uri = result.get("imageDataURI")
    if data_uri and "," in data_uri:
        return base64.b64decode(data_uri.split(",", 1)[1])
    url = result.get("imageURL")
    if url:
        try:
            resp = await client.get(url)
        except httpx.HTTPError as exc:
            raise GarmentImageError(
                "call_failed", f"Runware image download failed: {type(exc).__name__}"
            ) from exc
        if resp.status_code == 200 and resp.content:
            return resp.content
        raise GarmentImageError(
            "call_failed", f"Runware image download returned {resp.status_code}"
        )
    return None
