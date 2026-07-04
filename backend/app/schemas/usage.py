"""Phase 6d — usage tracking request/response shapes.

`UsageResource` keys the limit family being checked. `LimitReachedDetail` is
the body shape served back as a 429; the client uses `resets_at` to render
the countdown timer in the "100% Usage Limit Reached" screen.
"""
from __future__ import annotations

from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel

UsageResource = Literal["outfits", "mix_and_match", "buy_dont_buy", "advisor"]
SubscriptionTier = Literal["free", "pro"]


class UsageCounters(BaseModel):
    """Snapshot of one resource within the current week window."""

    used: int
    limit: int
    remaining: int
    percentage: float


class CurrentWeekUsage(BaseModel):
    week_start_date: date
    outfits: UsageCounters
    mix_and_match: UsageCounters
    buy_dont_buy: UsageCounters
    advisor: UsageCounters
    last_reset: datetime | None
    next_reset: datetime
    subscription_tier: SubscriptionTier


class LimitReachedDetail(BaseModel):
    error: Literal["limit_reached"] = "limit_reached"
    resource: UsageResource
    used: int
    limit: int
    resets_at: datetime
    message: str


class ProRequiredDetail(BaseModel):
    error: Literal["pro_required"] = "pro_required"
    feature: str
    message: str
