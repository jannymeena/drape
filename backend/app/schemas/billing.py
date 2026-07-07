"""Billing wire shapes (item 8b)."""
from __future__ import annotations

from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field

Plan = Literal["pro_monthly", "pro_yearly"]


class PlanSummary(BaseModel):
    plan: Plan
    price_cents: int
    currency: str


class PortalResponse(BaseModel):
    url: str


class SubscriptionResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    tier: Literal["free", "pro"]
    plan: Plan | None = None
    status: str | None = None
    price_cents: int | None = None
    currency: str | None = None
    current_period_start: datetime | None = None
    current_period_end: datetime | None = None
    cancel_at_period_end: bool = False
    retention_offer: str = "none"
    plans: list[PlanSummary]


class UpgradeRequest(BaseModel):
    plan: Plan


class CancelRequest(BaseModel):
    reason: str | None = Field(default=None, max_length=200)


class BillingRecordResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    description: str
    amount_cents: int
    currency: str
    status: str
    invoice_number: str | None
    occurred_at: datetime


class BillingHistoryResponse(BaseModel):
    records: list[BillingRecordResponse]


class PaymentMethodResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    kind: str
    brand: str
    last4: str
    exp_month: int
    exp_year: int
    is_default: bool


class PaymentMethodListResponse(BaseModel):
    methods: list[PaymentMethodResponse]


class AddPaymentMethodRequest(BaseModel):
    # Client-side token from the payment SDK; the mock accepts anything.
    token: str = Field(min_length=1, max_length=255)
