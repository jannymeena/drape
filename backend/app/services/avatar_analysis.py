"""§5.5 — derive body/skin metadata from the avatar photo.

Runs a single vision call (cached by §5.1's `CachingAIProvider`, so re-uploading
the same photo is free) and returns a small `{body_type, skin_tone,
styling_notes}` blob. That blob is persisted on the profile and fed into outfit
generation so suggestions account for the wearer's body and colouring — the
"rendered for you" link the POC `cli_claude.py` had and the app had dropped.

Best-effort by design: any failure (AI error, malformed JSON) returns `None` so
the avatar upload itself never breaks.

Scope is the avatar photo only. Measurements are a separate, consent-gated input
(see PROJECT_STATUS §5.5.1) and are intentionally NOT used here.
"""
from __future__ import annotations

import json
import re

import structlog

from app.services.providers.ai.base import AIProvider, AIProviderError

_log = structlog.get_logger("avatar.analysis")

_JSON_OBJECT_RE = re.compile(r"\{.*\}", re.DOTALL)

_ALLOWED_KEYS = ("body_type", "skin_tone", "styling_notes")

_PROMPT = (
    "You are a professional body and colour analyst assisting a fashion "
    "stylist. Analyze the person in this photo and respond with ONLY a JSON "
    "object — no prose, no markdown, no code fences. Schema:\n"
    "{\n"
    '  "body_type": "one of: rectangle, triangle, inverted_triangle, '
    'hourglass, oval, athletic, slim, average, broad",\n'
    '  "skin_tone": "short phrase, e.g. \\"warm/olive\\", \\"cool/fair\\", '
    '\\"deep/neutral\\"",\n'
    '  "styling_notes": "1-2 sentences of fit and colour guidance for this '
    'person"\n'
    "}\n"
    "If the photo does not clearly show a person, return the JSON with your "
    "best general estimate."
)


async def analyze_body(
    ai: AIProvider,
    *,
    image_bytes: bytes,
    media_type: str = "image/jpeg",
) -> dict | None:
    """Vision-analyze the avatar. Returns the cleaned blob, or None on any
    failure (never raises — callers treat None as "skip personalization")."""
    try:
        text = await ai.analyze_image(
            image_bytes, _PROMPT, media_type=media_type, max_tokens=400
        )
    except AIProviderError as exc:
        _log.warning("avatar.analysis.ai_failed", error=str(exc))
        return None

    parsed = _parse(text)
    if parsed is None:
        _log.warning("avatar.analysis.parse_failed")
    return parsed


def _parse(text: str) -> dict | None:
    candidate = text.strip()
    payload: object = None
    try:
        payload = json.loads(candidate)
    except json.JSONDecodeError:
        match = _JSON_OBJECT_RE.search(candidate)
        if match is not None:
            try:
                payload = json.loads(match.group(0))
            except json.JSONDecodeError:
                return None
    if not isinstance(payload, dict):
        return None

    # Keep only the known string keys; drop empties. Guards against the model
    # adding extra keys or returning non-string values.
    result = {
        k: payload[k].strip()
        for k in _ALLOWED_KEYS
        if isinstance(payload.get(k), str) and payload[k].strip()
    }
    return result or None
