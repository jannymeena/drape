"""Phase 6b — wardrobe scanner request/response shapes.

The detection itself is the 5-key shape produced by `AIProvider.analyze_image()`
(see `MockAIProvider.analyze_image` and `scanner_service._SCANNER_PROMPT`).
Confidence is an integer 0-100. Threshold semantics match the CTO doc:

  * confidence >= 70  -> auto-accept (suggest_manual_entry = False)
  * 50 <= confidence < 70  -> warn (200 with suggest_manual_entry = True)
  * confidence < 50  -> single-scan returns 400 low_confidence;
                         batch tags the row as status="low_confidence".
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.wardrobe import Category, Formality, Pattern


class ScanDetection(BaseModel):
    """The structured-output payload the scanner returns. Mirrors the keys
    `MockAIProvider.analyze_image` emits so dev runs match real-key runs."""

    model_config = ConfigDict(extra="ignore")

    category: Category
    color: str = Field(min_length=1, max_length=50)
    pattern: Pattern
    formality: Formality
    confidence: int = Field(ge=0, le=100)


class ScanItemResponse(BaseModel):
    detection: ScanDetection
    suggest_manual_entry: bool


BatchItemStatus = Literal["ok", "low_confidence", "error"]


class BatchUploadItem(BaseModel):
    """One row in the batch response. Status discriminates the optional fields:

      * ok / low_confidence -> `detection` is populated.
      * error -> `error_code` + `message` are populated; `detection` is null.
    """

    index: int = Field(ge=0)
    filename: str | None = None
    status: BatchItemStatus
    detection: ScanDetection | None = None
    suggest_manual_entry: bool = False
    error_code: str | None = None
    message: str | None = None


class BatchUploadResponse(BaseModel):
    results: list[BatchUploadItem]
    total: int
    succeeded: int
    low_confidence: int
    errored: int
