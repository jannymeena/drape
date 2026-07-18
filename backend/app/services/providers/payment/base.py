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
    def ensure_customer(
        self,
        *,
        user_id: UUID,
        email: str | None = None,
        name: str | None = None,
        customer_id: str | None = None,
    ) -> str | None:
        """Resolve (or create) the provider-side customer for this user and
        return its id for the caller to persist; None when the provider has no
        customer concept (mock). [email]/[name] are display identity only —
        the authoritative key upstream is metadata user_id. [customer_id] is
        the persisted mapping; when given, lookup round-trips are skipped."""

    @abstractmethod
    def create_subscription(
        self,
        *,
        user_id: UUID,
        plan: str,
        amount_cents: int,
        currency: str,
        customer_id: str | None = None,
        idempotency_key: str | None = None,
    ) -> ProviderSubscription:
        """Charge the first period and open the upstream subscription.

        [idempotency_key] identifies the logical attempt: a retry after a lost
        response replays the original result instead of double-charging."""

    @abstractmethod
    def cancel_subscription(self, *, provider_subscription_id: str) -> None:
        """Stop upstream renewal (entitlement runs to period end on our side)."""

    @abstractmethod
    def add_payment_method(
        self, *, user_id: UUID, token: str, customer_id: str | None = None
    ) -> ProviderPaymentMethod:
        """Exchange a client-side token for a stored payment method."""

    @abstractmethod
    def create_portal_url(
        self, *, user_id: UUID, customer_id: str | None = None
    ) -> str:
        """Short-lived URL to the provider-hosted billing management page."""
