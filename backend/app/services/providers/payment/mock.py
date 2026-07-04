"""Dev payment provider — instant success, deterministic-ish fake artifacts.

Lets the whole billing flow (upgrade -> Pro gates open -> cancel -> retention)
run end-to-end in dev with no Stripe account. Real money lands in
StripeProvider (Tier 3.2 / item 11c).
"""
from __future__ import annotations

import secrets
from uuid import UUID

import structlog

from app.services.providers.payment.base import (
    PaymentProvider,
    ProviderPaymentMethod,
    ProviderSubscription,
)

_log = structlog.get_logger("payment")


class MockPaymentProvider(PaymentProvider):
    def create_subscription(
        self, *, user_id: UUID, plan: str, amount_cents: int, currency: str
    ) -> ProviderSubscription:
        sub_id = f"mock_sub_{secrets.token_hex(8)}"
        invoice = f"INV-{secrets.token_hex(4).upper()}"
        _log.info(
            "payment.mock.subscribe",
            user_id=str(user_id),
            plan=plan,
            amount_cents=amount_cents,
            provider_subscription_id=sub_id,
        )
        return ProviderSubscription(
            provider_subscription_id=sub_id,
            invoice_number=invoice,
            amount_cents=amount_cents,
            currency=currency,
        )

    def cancel_subscription(self, *, provider_subscription_id: str) -> None:
        _log.info(
            "payment.mock.cancel",
            provider_subscription_id=provider_subscription_id,
        )

    def add_payment_method(
        self, *, user_id: UUID, token: str
    ) -> ProviderPaymentMethod:
        # The "token" is opaque; the mock mints a plausible Visa.
        return ProviderPaymentMethod(
            provider_payment_method_id=f"mock_pm_{secrets.token_hex(8)}",
            kind="card",
            brand="visa",
            last4=token[-4:] if token[-4:].isdigit() else "4242",
            exp_month=12,
            exp_year=2030,
        )
