"""Phase 6d — wardrobe analytics response shapes.

Cost-per-wear surfaces the same per-row math wardrobe_service already maintains;
the analytics endpoint just rolls items up by category and exposes the derived
columns. Utilization-score normalizes the "% of items worn in the last 30
days" metric the CTO doc references.
"""
from __future__ import annotations

from datetime import date
from uuid import UUID

from pydantic import BaseModel


class CostPerWearItem(BaseModel):
    item_id: UUID
    name: str
    category: str
    purchase_price: float | None
    worn_count: int
    cost_per_wear: float | None


class CostPerWearCategory(BaseModel):
    category: str
    item_count: int
    total_purchase_price: float
    total_wears: int
    average_cost_per_wear: float | None


class CostPerWearReport(BaseModel):
    items: list[CostPerWearItem]
    categories: list[CostPerWearCategory]
    total_items_with_price: int
    total_items_with_wears: int


class UtilizationScore(BaseModel):
    score: int
    items_worn_recently: int
    items_total: int
    days_window: int = 30
    label: str  # "Low" / "Moderate" / "High"


class WeeklyReportTopItem(BaseModel):
    item_id: UUID
    name: str
    worn_count: int


class WeeklyReport(BaseModel):
    """Free-tier visible — high-level numbers + small teaser block."""

    week_start_date: date
    outfits_logged: int
    items_worn_distinct: int
    top_items: list[WeeklyReportTopItem]
    streak_days: int
    pro_teaser: str = (
        "Upgrade to Pro for full intelligence reports — color palette, "
        "underutilized pieces, and seasonal forecasting."
    )


class IntelligenceColorBucket(BaseModel):
    color_name: str
    item_count: int
    worn_count: int


class IntelligenceUnderutilized(BaseModel):
    item_id: UUID
    name: str
    category: str
    worn_count: int
    days_since_last_worn: int | None


class IntelligenceReport(BaseModel):
    """Pro-only — full breakdown surfaced in the "Atelier Intelligence" tab."""

    total_items: int
    total_wears: int
    average_cost_per_wear: float | None
    color_palette: list[IntelligenceColorBucket]
    underutilized_items: list[IntelligenceUnderutilized]
    most_worn_category: str | None
    real_vs_starter_ratio: float
