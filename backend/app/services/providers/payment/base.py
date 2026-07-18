"""PaymentProvider interface — same @Profile-style pattern as AI/email/OAuth.

The provider owns only the *money movement* (creating/canceling the upstream
subscription, tokenizing cards). Our own `subscriptions` / `billing_history`
tables remain the source of truth for entitlement (users.subscription_tier).
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import ClassVar
from uuid import UUID


class PaymentProviderError(Exception):
    """Domain-level payment failure. Services translate to BillingError.

    code: 'payment_failed' (card declined & co — user-facing 402) or
    'payment_provider_error' (upstream unreachable/misbehaving — 502).
    """

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


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
    # Short slug persisted in subscriptions.provider (e.g. 'mock', 'stripe').
    name: ClassVar[str]

    @abstractmethod
    def create_subscription(
        self,
        *,
        user_id: UUID,
        plan: str,
        amount_cents: int,
        currency: str,
        email: str | None = None,
    ) -> ProviderSubscription:
        """Charge the first period and open the upstream subscription.

        [email] labels the upstream customer record so provider dashboards
        show a human identity instead of an opaque id; never used for lookup
        (metadata user_id is the key)."""

    @abstractmethod
    def cancel_subscription(self, *, provider_subscription_id: str) -> None:
        """Stop upstream renewal (entitlement runs to period end on our side)."""

    @abstractmethod
    def add_payment_method(
        self, *, user_id: UUID, token: str, email: str | None = None
    ) -> ProviderPaymentMethod:
        """Exchange a client-side token for a stored payment method."""

    @abstractmethod
    def create_portal_url(self, *, user_id: UUID, email: str | None = None) -> str:
        """Short-lived URL to the provider-hosted billing management page."""
