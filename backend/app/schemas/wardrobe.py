"""Phase 5c — wardrobe item request/response shapes.

Categorical fields use Pydantic Literals as the source of truth — DB columns
are plain VARCHARs so adding a value (new category, new pattern) doesn't need
a migration. Same pattern as 5a's shopping_style.
"""
from __future__ import annotations

from datetime import date, datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, field_validator

Category = Literal[
    "tops", "bottoms", "dresses", "shoes", "outerwear", "accessories", "bags", "jewelry"
]
Formality = Literal["casual", "smart_casual", "formal"]
Pattern = Literal["solid", "striped", "plaid", "floral", "graphic", "abstract", "other"]
Season = Literal["spring", "summer", "fall", "winter"]
AddedVia = Literal["manual", "scan", "batch_upload", "starter_seed"]

# Categorical filters use exact-match. Pagination caps at 200 — the tab is
# scrolled list, not a CSV export.
_LIST_LIMIT_DEFAULT = 50
_LIST_LIMIT_MAX = 200


class WardrobeItemBase(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    category: Category
    subcategory: str | None = Field(default=None, max_length=50)

    images: list[str] | None = None
    primary_image_url: str | None = Field(default=None, max_length=500)

    color_hex: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    color_name: str | None = Field(default=None, max_length=50)
    pattern: Pattern | None = None
    material: str | None = Field(default=None, max_length=100)
    formality: Formality | None = None
    season: list[Season] | None = None

    brand: str | None = Field(default=None, max_length=100)
    purchase_price: float | None = Field(default=None, ge=0)
    purchase_date: date | None = None
    description: str | None = Field(default=None, max_length=2000)


class AIDetection(BaseModel):
    """What the vision model said about a garment photo (the scanner's reply,
    plus the model id the backend stamps on it)."""

    model_config = ConfigDict(extra="ignore")

    category: Category
    # Garment type within the category, e.g. "ankle boots", "midi dress".
    subcategory: str | None = None
    color: str = Field(min_length=1, max_length=50)
    pattern: Pattern
    formality: Formality
    confidence: int = Field(ge=0, le=100)
    model: str | None = Field(default=None, max_length=100)

    @field_validator("subcategory", mode="before")
    @classmethod
    def _tidy_subcategory(cls, v: object) -> object:
        # A nice-to-have from the AI: clip it rather than fail the whole scan.
        if not isinstance(v, str):
            return None
        return v.strip().lower()[:50] or None


class WardrobeItemCreate(WardrobeItemBase):
    """Create from manual entry or a reviewed scan. Photos are attached
    separately via POST /wardrobe/items/{id}/images.

    A scanned item echoes the scanner's untouched `ai_detection` next to the
    (possibly user-corrected) fields above; the difference between the two is
    the scan accuracy signal."""

    added_via: Literal["manual", "scan", "batch_upload"] = "manual"
    ai_detection: AIDetection | None = None


class WardrobeItemUpdate(BaseModel):
    """Partial update — every field optional. Anything omitted is left alone."""

    name: str | None = Field(default=None, min_length=1, max_length=200)
    category: Category | None = None
    subcategory: str | None = Field(default=None, max_length=50)
    images: list[str] | None = None
    primary_image_url: str | None = Field(default=None, max_length=500)
    color_hex: str | None = Field(default=None, pattern=r"^#[0-9A-Fa-f]{6}$")
    color_name: str | None = Field(default=None, max_length=50)
    pattern: Pattern | None = None
    material: str | None = Field(default=None, max_length=100)
    formality: Formality | None = None
    season: list[Season] | None = None
    brand: str | None = Field(default=None, max_length=100)
    purchase_price: float | None = Field(default=None, ge=0)
    purchase_date: date | None = None
    description: str | None = Field(default=None, max_length=2000)


class WardrobeItemResponse(WardrobeItemBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    worn_count: int
    last_worn: date | None
    cost_per_wear: float | None
    is_favorite: bool
    favorited_at: datetime | None
    is_starter_wardrobe: bool
    # Starter items are AWIN products: the buy link for the "Buy" pill.
    product_id: UUID | None
    product_url: str | None = None
    added_via: AddedVia
    ai_detection_confidence: int | None
    created_at: datetime
    updated_at: datetime


class WardrobeListQuery(BaseModel):
    """Query params for GET /wardrobe — kept as a model so FastAPI generates
    a single canonical query schema in Swagger."""

    category: Category | None = None
    is_favorite: bool | None = None
    is_starter_wardrobe: bool | None = None
    limit: int = Field(default=_LIST_LIMIT_DEFAULT, ge=1, le=_LIST_LIMIT_MAX)
    offset: int = Field(default=0, ge=0)


class WardrobeListResponse(BaseModel):
    items: list[WardrobeItemResponse]
    total: int
    limit: int
    offset: int


class LogWornRequest(BaseModel):
    """If `worn_date` is omitted, server uses today (UTC)."""

    worn_date: date | None = None


class LogWornResponse(BaseModel):
    item_id: UUID
    worn_count: int
    last_worn: date
    cost_per_wear: float | None
    already_logged_today: bool


class ToggleFavoriteResponse(BaseModel):
    item_id: UUID
    is_favorite: bool
    favorited_at: datetime | None
