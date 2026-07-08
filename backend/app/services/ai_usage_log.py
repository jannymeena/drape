"""Dev AI usage/cost log (§5.3).

Appends one JSON line per AI call to a file (default `logs/ai_usage.jsonl`) so we
can manually compare models on real outputs. Called *after* the response returns
so the logged `output` is the actual model result, not a prediction.

Disabled unless `settings.ai_usage_log_enabled` (a dev tool; prd uses a DB table
later). Never raises — a logging failure must not break the request.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from io import BytesIO
from pathlib import Path
from typing import Optional

import structlog

from app.core.config import settings
from app.services import ai_pricing

_log = structlog.get_logger("ai.usage")


def _image_meta(image_bytes: bytes, media_type: Optional[str]) -> dict:
    """Size always; width/height when Pillow is available (a dev dep)."""
    meta: dict = {
        "size_bytes": len(image_bytes),
        "mime": media_type,
        "width": None,
        "height": None,
    }
    try:
        from PIL import Image  # lazy: only the dev logging path needs it

        with Image.open(BytesIO(image_bytes)) as im:
            meta["width"], meta["height"] = im.size
    except Exception:
        pass  # Pillow missing or undecodable — size/mime still useful
    return meta


def record(
    *,
    model: str,
    call_type: str,  # "chat" | "analyze_image"
    input_tokens: int,
    output_tokens: int,
    latency_ms: int,
    output: str,
    cached: bool = False,
    cache_creation_input_tokens: int = 0,
    cache_read_input_tokens: int = 0,
    image_bytes: Optional[bytes] = None,
    media_type: Optional[str] = None,
) -> None:
    if not settings.ai_usage_log_enabled:
        return
    try:
        cost = (
            0.0
            if cached
            else ai_pricing.cost_usd(
                model,
                input_tokens,
                output_tokens,
                cache_creation_input_tokens=cache_creation_input_tokens,
                cache_read_input_tokens=cache_read_input_tokens,
            )
        )
        entry: dict = {
            "ts": datetime.now(timezone.utc).isoformat(),
            "model": model,
            "call_type": call_type,
            "latency_ms": latency_ms,
            "input_tokens": input_tokens,
            "output_tokens": output_tokens,
            "cache_creation_input_tokens": cache_creation_input_tokens,
            "cache_read_input_tokens": cache_read_input_tokens,
            "cost_usd": round(cost, 6),
            "cached": cached,
            "output": output,
        }
        if image_bytes is not None:
            entry["image"] = _image_meta(image_bytes, media_type)

        path = Path(settings.ai_usage_log_path)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
    except Exception as exc:  # telemetry must never break the request
        _log.warning("ai.usage.log_write_failed", error=str(exc))
