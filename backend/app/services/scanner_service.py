"""Phase 6b — wardrobe scanner.

Wraps `AIProvider.analyze_image()` with a structured-output prompt, parses the
response into `ScanDetection`, and applies confidence thresholds. Routes call
`scan_one()` (single image) or `scan_batch()` (up to 12).

Error model:

  * `ScannerError("ai_call_failed", ...)`  -> upstream AIProvider raised.
  * `ScannerError("parse_failed", ...)`    -> AI text wasn't JSON / didn't match schema.
  * `ScannerError("low_confidence", ...)`  -> confidence < LOW_CONFIDENCE_THRESHOLD.

`scan_batch` never raises per-item — it folds each failure into a
`BatchUploadItem` so the client can render mixed results in one pass.
"""
from __future__ import annotations

import asyncio
import json
import re
from json import JSONDecodeError

import structlog
from pydantic import ValidationError

from app.schemas.scanner import BatchUploadItem, BatchUploadResponse, ScanDetection
from app.schemas.wardrobe import Category, Formality, Pattern
from app.services.providers.ai.base import AIProvider, AIProviderError

# Confidence thresholds — see schemas/scanner.py docstring for the 70/50 split.
LOW_CONFIDENCE_THRESHOLD = 50
WARN_CONFIDENCE_THRESHOLD = 70

# CTO doc: "Add up to 12 items at once from your photo library".
MAX_BATCH_SIZE = 12

# Concurrency bound for batch scans. Anthropic's API tolerates parallel requests
# but we cap to keep tail latency predictable and stay well under the rate limit.
_BATCH_CONCURRENCY = 4

_log = structlog.get_logger("scanner")

# Allowed enum values are sourced from the wardrobe schemas — keeps the prompt
# and the Pydantic validator in lockstep when categories evolve.
_CATEGORIES = list(Category.__args__)  # type: ignore[attr-defined]
_PATTERNS = list(Pattern.__args__)  # type: ignore[attr-defined]
_FORMALITIES = list(Formality.__args__)  # type: ignore[attr-defined]

_SCANNER_PROMPT = (
    "You are a wardrobe scanner. Analyze the clothing item in the image.\n"
    "Respond with ONLY a JSON object — no prose, no markdown, no code fences. "
    "The object MUST match this exact schema:\n"
    "{\n"
    f'  "category": one of {_CATEGORIES},\n'
    '  "color": short color name (e.g., "blue", "white", "navy"),\n'
    f'  "pattern": one of {_PATTERNS},\n'
    f'  "formality": one of {_FORMALITIES},\n'
    '  "confidence": integer 0-100 — how confident you are in the identification\n'
    "}\n"
    "If the image does not clearly contain a single clothing item, return your "
    "best guess for category/color/pattern/formality and set confidence to a "
    "low value (under 50)."
)

# LLMs sometimes wrap JSON in prose ("Here is the analysis: {...}"). This grabs
# the first balanced-looking object so we can recover from minor pre/postfix.
_JSON_OBJECT_RE = re.compile(r"\{.*\}", re.DOTALL)


class ScannerError(Exception):
    """Domain-level scanner failure. Routes translate `low_confidence` to 400,
    `parse_failed` / `ai_call_failed` to 502."""

    def __init__(
        self,
        code: str,
        message: str,
        *,
        detection: ScanDetection | None = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.detection = detection


def _parse_detection(text: str) -> ScanDetection:
    """Best-effort JSON extraction + Pydantic validation. Raises ScannerError
    with code='parse_failed' on any structural failure."""
    candidate = text.strip()
    try:
        payload = json.loads(candidate)
    except JSONDecodeError:
        match = _JSON_OBJECT_RE.search(candidate)
        if match is None:
            raise ScannerError(
                "parse_failed", "AI response did not contain a JSON object"
            )
        try:
            payload = json.loads(match.group(0))
        except JSONDecodeError as exc:
            raise ScannerError(
                "parse_failed", f"AI response had malformed JSON: {exc}"
            ) from exc
    try:
        return ScanDetection.model_validate(payload)
    except ValidationError as exc:
        raise ScannerError(
            "parse_failed", f"AI response failed schema validation: {exc.errors()}"
        ) from exc


async def scan_one(
    ai: AIProvider,
    *,
    image_bytes: bytes,
    media_type: str,
) -> ScanDetection:
    """Single-image scan. Raises ScannerError on every non-success path; the
    caller (route or scan_batch) translates per their needs."""
    try:
        text = await ai.analyze_image(image_bytes, _SCANNER_PROMPT, media_type=media_type)
    except AIProviderError as exc:
        _log.warning("scanner.ai_call_failed", code=exc.code, error=str(exc))
        raise ScannerError("ai_call_failed", str(exc)) from exc

    detection = _parse_detection(text)

    if detection.confidence < LOW_CONFIDENCE_THRESHOLD:
        _log.info(
            "scanner.low_confidence",
            confidence=detection.confidence,
            category=detection.category,
        )
        raise ScannerError(
            "low_confidence",
            f"AI confidence {detection.confidence} below threshold {LOW_CONFIDENCE_THRESHOLD}",
            detection=detection,
        )

    _log.info(
        "scanner.scanned",
        confidence=detection.confidence,
        category=detection.category,
        pattern=detection.pattern,
    )
    return detection


def suggest_manual_entry(detection: ScanDetection) -> bool:
    """True for borderline confidence (50-69). UI shows the result but flags it."""
    return detection.confidence < WARN_CONFIDENCE_THRESHOLD


async def scan_batch(
    ai: AIProvider,
    *,
    uploads: list[tuple[bytes, str, str | None]],
) -> BatchUploadResponse:
    """Run scans concurrently (capped by `_BATCH_CONCURRENCY`).

    `uploads` is a list of `(image_bytes, media_type, filename | None)`.
    Per-item failures become rows with `status='low_confidence'` or `'error'`
    rather than raising — the route returns a single 200 with the mixed result.
    """
    if not uploads:
        return BatchUploadResponse(results=[], total=0, succeeded=0, low_confidence=0, errored=0)
    if len(uploads) > MAX_BATCH_SIZE:
        # Defensive — the route already enforces this, but keep the service
        # honest in case callers grow.
        raise ScannerError(
            "batch_too_large",
            f"Batch size {len(uploads)} exceeds max {MAX_BATCH_SIZE}",
        )

    sem = asyncio.Semaphore(_BATCH_CONCURRENCY)

    async def _run(index: int, item: tuple[bytes, str, str | None]) -> BatchUploadItem:
        content, media_type, filename = item
        async with sem:
            try:
                detection = await scan_one(ai, image_bytes=content, media_type=media_type)
            except ScannerError as exc:
                if exc.code == "low_confidence" and exc.detection is not None:
                    return BatchUploadItem(
                        index=index,
                        filename=filename,
                        status="low_confidence",
                        detection=exc.detection,
                        suggest_manual_entry=True,
                        error_code="low_confidence",
                        message=str(exc),
                    )
                return BatchUploadItem(
                    index=index,
                    filename=filename,
                    status="error",
                    error_code=exc.code,
                    message=str(exc),
                )
        return BatchUploadItem(
            index=index,
            filename=filename,
            status="ok",
            detection=detection,
            suggest_manual_entry=suggest_manual_entry(detection),
        )

    results = await asyncio.gather(*(_run(i, u) for i, u in enumerate(uploads)))

    succeeded = sum(1 for r in results if r.status == "ok")
    low = sum(1 for r in results if r.status == "low_confidence")
    errored = sum(1 for r in results if r.status == "error")
    _log.info(
        "scanner.batch_complete",
        total=len(results),
        succeeded=succeeded,
        low_confidence=low,
        errored=errored,
    )
    return BatchUploadResponse(
        results=list(results),
        total=len(results),
        succeeded=succeeded,
        low_confidence=low,
        errored=errored,
    )
