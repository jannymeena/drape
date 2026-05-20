"""Phase 6b verify — wardrobe scanner + batch upload.

Usage (from backend/, with the venv active):

    python scripts/verify_phase_6b.py

The five checks correspond to plan.md §7 Phase 6b Verify plus a parse-failure
guard:

  1. scan_one() returns a valid ScanDetection (5 keys, confidence 0-100).
  2. scan_batch() of 12 returns 12 results — counters add up.
  3. Confidence < 50 raises ScannerError("low_confidence") and embeds the
     parsed detection so the route can echo it back.
  4. Round-trip: detected attrs satisfy WardrobeItemCreate (the schema the
     client posts to /wardrobe/items).
  5. Malformed AI output raises ScannerError("parse_failed") rather than
     bubbling raw json.JSONDecodeError.

Real-key path: if ANTHROPIC_API_KEY is set, check 1 hits the real Anthropic
vision API. Checks 3+5 always use a stub provider so they're deterministic.
"""
from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.core.providers import providers  # noqa: E402
from app.schemas.scanner import ScanDetection  # noqa: E402
from app.schemas.wardrobe import WardrobeItemCreate  # noqa: E402
from app.services import scanner_service  # noqa: E402
from app.services.providers.ai.base import AIProvider  # noqa: E402
from app.services.scanner_service import (  # noqa: E402
    LOW_CONFIDENCE_THRESHOLD,
    MAX_BATCH_SIZE,
    ScannerError,
    scan_batch,
    scan_one,
)


def _ok(label: str, detail: str = "") -> None:
    suffix = f" — {detail}" if detail else ""
    print(f"  [PASS] {label}{suffix}")


def _fail(label: str, detail: str) -> None:
    print(f"  [FAIL] {label} — {detail}")


# A 16-byte non-image stub. Mock provider ignores bytes; real provider would
# reject this — checks 2/3/5 use the canned providers below to stay offline.
_FAKE_JPEG = b"\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01" + b"\x00" * 64


class _CannedAIProvider(AIProvider):
    """Returns whatever JSON string is queued. Used to drive the
    low_confidence and parse_failed checks deterministically."""

    def __init__(self, payloads: list[str]) -> None:
        self._payloads = list(payloads)

    async def chat(self, messages, *, model=None, system=None, max_tokens=1024):  # type: ignore[override]
        raise NotImplementedError("scanner does not call chat")

    async def analyze_image(  # type: ignore[override]
        self, image_bytes, prompt, *, media_type="image/jpeg", model=None, max_tokens=1024
    ):
        if not self._payloads:
            raise RuntimeError("CannedAIProvider exhausted")
        return self._payloads.pop(0)


async def check_scan_one() -> bool:
    print("[1] scan_one() returns valid ScanDetection")
    try:
        detection = await scan_one(
            providers.ai, image_bytes=_FAKE_JPEG, media_type="image/jpeg"
        )
    except Exception as exc:  # noqa: BLE001
        _fail("scan_one", f"raised: {exc!r}")
        return False
    if not isinstance(detection, ScanDetection):
        _fail("scan_one", f"wrong type: {type(detection).__name__}")
        return False
    if not (0 <= detection.confidence <= 100):
        _fail("scan_one", f"confidence out of range: {detection.confidence}")
        return False
    _ok(
        "scan_one",
        f"category={detection.category}, color={detection.color!r}, "
        f"pattern={detection.pattern}, formality={detection.formality}, "
        f"confidence={detection.confidence}",
    )
    return True


async def check_scan_batch() -> bool:
    print(f"[2] scan_batch() of {MAX_BATCH_SIZE} returns {MAX_BATCH_SIZE} results")
    uploads = [(_FAKE_JPEG, "image/jpeg", f"item-{i}.jpg") for i in range(MAX_BATCH_SIZE)]
    try:
        resp = await scan_batch(providers.ai, uploads=uploads)
    except Exception as exc:  # noqa: BLE001
        _fail("scan_batch", f"raised: {exc!r}")
        return False
    if resp.total != MAX_BATCH_SIZE or len(resp.results) != MAX_BATCH_SIZE:
        _fail(
            "scan_batch",
            f"expected {MAX_BATCH_SIZE} results, got total={resp.total}, len={len(resp.results)}",
        )
        return False
    if resp.succeeded + resp.low_confidence + resp.errored != MAX_BATCH_SIZE:
        _fail(
            "scan_batch",
            f"counters don't sum to total: ok={resp.succeeded}, "
            f"low={resp.low_confidence}, err={resp.errored}",
        )
        return False
    indices = sorted(r.index for r in resp.results)
    if indices != list(range(MAX_BATCH_SIZE)):
        _fail("scan_batch", f"indices not 0..{MAX_BATCH_SIZE - 1}: {indices}")
        return False
    _ok(
        "scan_batch",
        f"ok={resp.succeeded}, low_confidence={resp.low_confidence}, errored={resp.errored}",
    )
    return True


async def check_low_confidence() -> bool:
    print(f"[3] confidence < {LOW_CONFIDENCE_THRESHOLD} raises ScannerError(low_confidence)")
    canned = _CannedAIProvider(
        [
            json.dumps(
                {
                    "category": "tops",
                    "color": "white",
                    "pattern": "solid",
                    "formality": "casual",
                    "confidence": 42,
                }
            )
        ]
    )
    try:
        await scan_one(canned, image_bytes=_FAKE_JPEG, media_type="image/jpeg")
    except ScannerError as exc:
        if exc.code != "low_confidence":
            _fail("low_confidence", f"wrong code: {exc.code!r}")
            return False
        if exc.detection is None or exc.detection.confidence != 42:
            _fail("low_confidence", f"detection not embedded correctly: {exc.detection!r}")
            return False
        _ok("low_confidence", f"code={exc.code}, embedded confidence={exc.detection.confidence}")
        return True
    except Exception as exc:  # noqa: BLE001
        _fail("low_confidence", f"raised non-ScannerError: {exc!r}")
        return False
    _fail("low_confidence", "no error raised on confidence=42")
    return False


async def check_round_trip() -> bool:
    print("[4] round-trip: detection satisfies WardrobeItemCreate")
    detection = await scan_one(
        providers.ai, image_bytes=_FAKE_JPEG, media_type="image/jpeg"
    )
    try:
        item = WardrobeItemCreate(
            name=f"Scanned {detection.color} {detection.category[:-1]}",
            category=detection.category,
            color_name=detection.color,
            pattern=detection.pattern,
            formality=detection.formality,
        )
    except Exception as exc:  # noqa: BLE001
        _fail("round_trip", f"WardrobeItemCreate rejected detection: {exc!r}")
        return False
    if item.category != detection.category or item.pattern != detection.pattern:
        _fail("round_trip", f"item fields don't match detection: {item!r}")
        return False
    _ok("round_trip", f"WardrobeItemCreate accepted name={item.name!r}, category={item.category}")
    return True


async def check_parse_failed() -> bool:
    print("[5] malformed AI output raises ScannerError(parse_failed)")
    canned = _CannedAIProvider(["definitely not json — sorry!"])
    try:
        await scan_one(canned, image_bytes=_FAKE_JPEG, media_type="image/jpeg")
    except ScannerError as exc:
        if exc.code != "parse_failed":
            _fail("parse_failed", f"wrong code: {exc.code!r}")
            return False
        _ok("parse_failed", f"code={exc.code}")
        return True
    except Exception as exc:  # noqa: BLE001
        _fail("parse_failed", f"raised non-ScannerError: {exc!r}")
        return False
    _fail("parse_failed", "no error raised on bad JSON")
    return False


async def main() -> int:
    print(f"=== Phase 6b verify (ENVIRONMENT={settings.environment}) ===")
    print(f"providers.ai = {type(providers.ai).__name__}")
    print()

    results = [
        await check_scan_one(),
        await check_scan_batch(),
        await check_low_confidence(),
        await check_round_trip(),
        await check_parse_failed(),
    ]
    print()
    passed = sum(1 for r in results if r)
    total = len(results)
    print(f"=== {passed}/{total} checks passed ===")
    return 0 if passed == total else 1


if __name__ == "__main__":
    sys.exit(asyncio.run(main()))
