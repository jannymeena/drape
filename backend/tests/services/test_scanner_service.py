"""Scanner service — `_parse_detection` / `scan_one` error-model coverage.

The not_a_garment escape hatch exists because the live model, shown a
non-garment photo, ignored the "guess with low confidence" instruction and
emitted `category: 'none'` etc., which failed schema validation and surfaced
as a 502 (found on tbd 2026-07-20). Non-garment images must be a typed
rejection, not a parse failure.
"""
from __future__ import annotations

import json

import pytest

from app.services import scanner_service
from app.services.providers.ai.base import AIProvider
from app.services.scanner_service import ScannerError, _parse_detection, scan_one


class _FixedAIProvider(AIProvider):
    """Returns a fixed analyze_image payload; chat is unused here."""

    def __init__(self, response: str) -> None:
        self._response = response

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024,
                   cache_system=False) -> str:  # pragma: no cover - unused
        raise NotImplementedError

    async def analyze_image(self, image_bytes, prompt, *, media_type="image/jpeg",
                            model=None, max_tokens=1024) -> str:
        return self._response


_GARMENT = {
    "category": "tops",
    "color": "blue",
    "pattern": "solid",
    "formality": "casual",
    "confidence": 85,
}


def test_parse_detection_accepts_garment_payload():
    detection = _parse_detection(json.dumps(_GARMENT))
    assert detection.category == "tops"
    assert detection.confidence == 85


def test_parse_detection_not_a_garment_is_typed_rejection():
    payload = {"not_a_garment": True, "reason": "a field of flowers"}
    with pytest.raises(ScannerError) as exc_info:
        _parse_detection(json.dumps(payload))
    assert exc_info.value.code == "not_a_garment"
    assert "flowers" in str(exc_info.value)


def test_parse_detection_not_a_garment_without_reason_gets_default_message():
    with pytest.raises(ScannerError) as exc_info:
        _parse_detection(json.dumps({"not_a_garment": True}))
    assert exc_info.value.code == "not_a_garment"
    assert str(exc_info.value)  # non-empty message for the client


def test_parse_detection_invalid_literals_still_parse_failed():
    # The exact live-failure shape: model invents out-of-enum literals without
    # using the escape hatch. Stays a 502-class parse failure.
    payload = {**_GARMENT, "category": "none", "pattern": "none", "formality": "unknown"}
    with pytest.raises(ScannerError) as exc_info:
        _parse_detection(json.dumps(payload))
    assert exc_info.value.code == "parse_failed"


async def test_scan_one_raises_not_a_garment():
    ai = _FixedAIProvider('{"not_a_garment": true, "reason": "landscape photo"}')
    with pytest.raises(ScannerError) as exc_info:
        await scan_one(ai, image_bytes=b"x", media_type="image/png")
    assert exc_info.value.code == "not_a_garment"


async def test_scan_batch_folds_not_a_garment_into_error_row():
    ai = _FixedAIProvider('{"not_a_garment": true, "reason": "landscape photo"}')
    result = await scanner_service.scan_batch(
        ai, uploads=[(b"x", "image/png", "landscape.png")]
    )
    assert result.total == 1
    assert result.errored == 1
    row = result.results[0]
    assert row.status == "error"
    assert row.error_code == "not_a_garment"
