"""Phase 6c — outfit + today dashboard request/response shapes.

`Occasion` is the source-of-truth Literal for valid occasions; the DB column is
plain VARCHAR per the same convention as wardrobe.py (Pydantic Literal owns the
allowed-values set so adding "weekend" doesn't need a migration).

Item references inside an outfit are stored as JSONB on the row but exposed as
typed `OutfitItem` objects on the wire — the client renders them client-side
(2x2 grid per plan.md decision #2; no server-side composites).
"""
from __future__ import annotations

from datetime import date, datetime
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

Occasion = Literal["work", "casual", "gym", "date_night", "other"]
GenerationMethod = Literal["anthropic_v1", "manual_mix"]
ToastVariant = Literal["milestone", "streak", "default"]


class OutfitItem(BaseModel):
    """Per-item snapshot baked into the outfit row. Carrying name/category/
    primary_image_url denormalized means historical outfits stay readable even
    if the underlying wardrobe_item is later edited or deleted."""

    item_id: UUID
    name: str
    category: str
    primary_image_url: str | None = None
    color_name: str | None = None
    formality: str | None = None
    why_it_works: str | None = None
    is_starter_wardrobe: bool = False


class WeatherContext(BaseModel):
    temp_c: float
    feels_like_c: float
    condition: str
    humidity_pct: int | None = None
    wind_kph: float | None = None


class OutfitResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    user_id: UUID
    occasion: Occasion
    items: list[OutfitItem]
    image_url: str | None
    ai_reasoning_short: str | None
    ai_reasoning_full: str | None
    compatibility_score: int | None
    weather_context: WeatherContext | None
    using_starter_wardrobe: bool
    generation_method: GenerationMethod
    is_logged: bool
    logged_at: datetime | None
    worn_count: int
    is_favorite: bool = False
    created_at: datetime
    updated_at: datetime


class OutfitFavoriteResponse(BaseModel):
    outfit_id: UUID
    is_favorite: bool
    favorited_at: datetime | None


class GenerateOutfitsRequest(BaseModel):
    """Optional context overrides. When omitted, occasions default to
    [work, casual, date_night] (CTO doc) and the user's stored timezone /
    location drives the weather lookup."""

    occasions: list[Occasion] | None = None
    lat: float | None = None
    lon: float | None = None


class GenerateOutfitsResponse(BaseModel):
    outfits: list[OutfitResponse]
    using_starter_wardrobe: bool


class GenerateOccasionRequest(BaseModel):
    """Single-occasion generation for the Today dashboard's incremental fill.

    The client fires one of these per pending occasion (in parallel) so each
    outfit card resolves independently instead of waiting on a 3-call batch.
    Unlike `/today/generate-outfits`, this is part of the free daily fill and
    does not consume a weekly outfit credit."""

    occasion: Occasion
    lat: float | None = None
    lon: float | None = None


class TodayUser(BaseModel):
    name: str
    location: str | None
    timezone: str | None


class BannerDismissResponse(BaseModel):
    banner: str
    dismissed_at: datetime
    hidden_for_days: int


class TodayBanners(BaseModel):
    starter_wardrobe: bool = False
    incomplete_profile: bool = False


class TodayUsage(BaseModel):
    """Stub usage counters. Real free-tier enforcement lands in 6d; for 6c
    the dashboard reports the count of outfits generated today vs the soft
    target so the client can show progress without 4xx-blocking the user."""

    outfits_generated_today: int
    outfit_target_per_day: int = 3
    resets_at: datetime | None = None


class TodayDashboardResponse(BaseModel):
    user: TodayUser
    weather: WeatherContext | None
    outfits: list[OutfitResponse]
    usage: TodayUsage
    banners: TodayBanners
    # The dashboard is now read-only: it no longer generates outfits inline.
    # `wardrobe_ready` tells the client whether outfit generation is possible at
    # all (>= 2 items); `pending_occasions` is the set of occasions that still
    # need a today-outfit. The client renders a skeleton per pending occasion and
    # fills each via POST /today/outfits. Defaults keep older clients compatible.
    wardrobe_ready: bool = False
    pending_occasions: list[Occasion] = Field(default_factory=list)


class ReasoningItem(BaseModel):
    item_id: UUID
    name: str
    why_it_works: str | None
    image_url: str | None = None
    # For the client's coloured category-silhouette placeholder when the item
    # has no photo.
    category: str | None = None
    color_name: str | None = None


class OutfitReasoningResponse(BaseModel):
    outfit_id: UUID
    full_text: str | None
    items: list[ReasoningItem]
    compatibility_score: int | None
    compatibility_label: str
    factors: list[str]


class MixSwap(BaseModel):
    old_item_id: UUID
    new_item_id: UUID


class MixAndMatchRequest(BaseModel):
    swapped_items: list[MixSwap] = Field(min_length=1)


class MixAndMatchResponse(BaseModel):
    outfit_id: UUID
    items: list[OutfitItem]
    compatibility_score: int
    image_url: str | None


class LogOutfitToast(BaseModel):
    type: ToastVariant
    message: str
    duration_ms: int
    background: str
    haptic: str


class LogOutfitResponse(BaseModel):
    outfit_id: UUID
    logged_at: datetime
    current_streak: int
    longest_streak: int
    total_outfits_logged: int
    toast: LogOutfitToast


HistoryFilter = Literal["this_week", "this_month", "last_3_months", "all"]


class HistoryStreak(BaseModel):
    days: int
    started_at: date | None
    is_active: bool


class HistoryEntry(BaseModel):
    outfit_id: UUID
    logged_at: datetime
    occasion: Occasion
    items_count: int
    worn_count: int
    image_url: str | None
    items: list[OutfitItem]


class OutfitHistoryResponse(BaseModel):
    outfits: list[HistoryEntry]
    total_count: int
    current_streak: HistoryStreak
    filter: HistoryFilter


class StructuredOutfitProposal(BaseModel):
    """Schema we ask Claude to fill via structured output. Used internally in
    outfit_service to validate the LLM's reply before persisting."""

    model_config = ConfigDict(extra="ignore")

    occasion: Occasion
    item_ids: list[UUID] = Field(min_length=2, max_length=8)
    reasoning_short: str = Field(min_length=1, max_length=500)
    reasoning_full: str = Field(min_length=1, max_length=4000)
    per_item_rationales: dict[str, str] = Field(default_factory=dict)
    compatibility_score: int = Field(ge=0, le=100)
    factors: list[str] = Field(default_factory=list)


class GeneratedOutfitDraft(BaseModel):
    """Internal — what outfit_service.generate_one returns before persistence.
    Lets the dashboard reuse the same generation path for force-generate."""

    occasion: Occasion
    items: list[OutfitItem]
    weather_context: WeatherContext | None
    using_starter_wardrobe: bool
    proposal: StructuredOutfitProposal
    generation_method: GenerationMethod


# A loose payload shape for the items-JSONB column; exposed so the service can
# persist and the route can read with one canonical conversion.
def outfit_items_to_payload(items: list[OutfitItem]) -> list[dict[str, Any]]:
    return [item.model_dump(mode="json") for item in items]


def payload_to_outfit_items(payload: list[dict[str, Any]] | None) -> list[OutfitItem]:
    if not payload:
        return []
    return [OutfitItem.model_validate(p) for p in payload]
