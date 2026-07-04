"""Real Stripe provider — Tier 3.2 / item 11c. Blocked on test keys + price
ids; mirrors the KMS/OAuth pattern of raising until implemented."""
from __future__ import annotations

from uuid import UUID

from app.services.providers.payment.base import (
    PaymentProvider,
    ProviderPaymentMethod,
    ProviderSubscription,
)


class StripeProvider(PaymentProvider):
    def __init__(self, *, api_key: str) -> None:
        self._api_key = api_key

    def create_subscription(
        self, *, user_id: UUID, plan: str, amount_cents: int, currency: str
    ) -> ProviderSubscription:
        raise NotImplementedError("StripeProvider lands in 11c (Tier 3.2)")

    def cancel_subscription(self, *, provider_subscription_id: str) -> None:
        raise NotImplementedError("StripeProvider lands in 11c (Tier 3.2)")

    def add_payment_method(
        self, *, user_id: UUID, token: str
    ) -> ProviderPaymentMethod:
        raise NotImplementedError("StripeProvider lands in 11c (Tier 3.2)")
