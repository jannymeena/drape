"""PaymentProvider interface — same @Profile-style pattern as AI/email/OAuth.

The provider owns only the *money movement* (creating/canceling the upstream
subscription, tokenizing cards). Our own `subscriptions` / `billing_history`
tables remain the source of truth for entitlement (users.subscription_tier).
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class ProviderSubscription:
    provider_subscription_id: str
    invoice_number: str
    amount_cents: int
    currency: str


@dataclass(frozen=True)
class ProviderPaymentMethod:
    provider_payment_method_id: str
    kind: str  # 'card' | 'apple_pay'
    brand: str
    last4: str
    exp_month: int
    exp_year: int


class PaymentProvider(ABC):
    @abstractmethod
    def create_subscription(
        self, *, user_id: UUID, plan: str, amount_cents: int, currency: str
    ) -> ProviderSubscription:
        """Charge the first period and open the upstream subscription."""

    @abstractmethod
    def cancel_subscription(self, *, provider_subscription_id: str) -> None:
        """Stop upstream renewal (entitlement runs to period end on our side)."""

    @abstractmethod
    def add_payment_method(
        self, *, user_id: UUID, token: str
    ) -> ProviderPaymentMethod:
        """Exchange a client-side token for a stored payment method."""
