"""Shop wire shapes (items 7a-7e)."""
from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field


class ProductResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    name: str
    brand: str
    category: str
    price_cents: int
    currency: str
    image_url: str
    product_url: str
    retailer: str


class ShopFeedResponse(BaseModel):
    products: list[ProductResponse]
    measurements_complete: bool


class AdvisorAskRequest(BaseModel):
    question: str = Field(min_length=1, max_length=500)
    conversation_id: UUID | None = None


class AdvisorSuggestion(BaseModel):
    name: str
    category: str
    reason: str
    product_id: UUID | None = None


class AdvisorMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str
    suggestions: list[AdvisorSuggestion] | None = None


class AdvisorConversationResponse(BaseModel):
    id: UUID
    title: str
    messages: list[AdvisorMessage]
    updated_at: datetime


class AdvisorHistoryResponse(BaseModel):
    conversations: list[AdvisorConversationResponse]


class BuyDontBuyResponse(BaseModel):
    id: UUID
    product_name: str | None
    verdict: Literal["buy", "dont_buy"]
    score: int
    fit_reason: str
    value_reason: str
    gap_reason: str
    created_at: datetime


class BuyDontBuyHistoryResponse(BaseModel):
    checks: list[BuyDontBuyResponse]


class GapItem(BaseModel):
    category: str
    have: int
    recommended: int
    reason: str
    outfits_unlocked: int


class GapAnalysisResponse(BaseModel):
    gaps: list[GapItem]
    is_teaser: bool  # free tier sees only the top gap
    pro_teaser: str | None = None


class WishlistAddRequest(BaseModel):
    product_id: UUID


class WishlistEntry(BaseModel):
    product: ProductResponse
    added_price_cents: int
    current_price_cents: int | None
    price_drop_cents: int  # 0 when no drop
    added_at: datetime


class WishlistResponse(BaseModel):
    items: list[WishlistEntry]
