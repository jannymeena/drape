"""Real Stripe provider (item 11c) — money movement over Stripe's REST API.

No SDK: the handful of endpoints we need are plain form-encoded calls, so
httpx + stdlib HMAC keep the dependency set unchanged. Our own tables stay
the entitlement source of truth (billing_service is the only writer); the
webhook route applies renewals/failures/deletions via
billing_service.apply_stripe_event.

Customer mapping: one Stripe customer per user, found by metadata user_id
search and created with a deterministic idempotency key on miss — the
idempotency key covers the search-index lag window right after creation,
so the add-payment-method → upgrade burst can't mint duplicates. Memoized
per process.
"""
from __future__ import annotations

import hashlib
import hmac
import time
from typing import Any
from uuid import UUID

import httpx
import structlog

from app.services.providers.payment.base import (
    PaymentProvider,
    PaymentProviderError,
    ProviderPaymentMethod,
    ProviderSubscription,
)

_log = structlog.get_logger("payment.stripe")

_BASE_URL = "https://api.stripe.com/v1"
_TIMEOUT_S = 20.0
_WEBHOOK_TOLERANCE_S = 300


def verify_webhook_signature(
    payload: bytes, signature_header: str, secret: str, *, tolerance_s: int = _WEBHOOK_TOLERANCE_S
) -> None:
    """Validate a Stripe-Signature header (t=...,v1=...) against the raw body.

    Raises PaymentProviderError('invalid_signature') on any failure — missing
    parts, stale timestamp (replay guard), or MAC mismatch.
    """
    timestamp: int | None = None
    candidates: list[str] = []
    for part in signature_header.split(","):
        key, _, value = part.strip().partition("=")
        if key == "t" and value.isdigit():
            timestamp = int(value)
        elif key == "v1":
            candidates.append(value)
    if timestamp is None or not candidates:
        raise PaymentProviderError("invalid_signature", "Malformed Stripe-Signature header")
    if abs(time.time() - timestamp) > tolerance_s:
        raise PaymentProviderError("invalid_signature", "Stripe-Signature timestamp too old")
    expected = hmac.new(
        secret.encode(), f"{timestamp}.".encode() + payload, hashlib.sha256
    ).hexdigest()
    if not any(hmac.compare_digest(expected, candidate) for candidate in candidates):
        raise PaymentProviderError("invalid_signature", "Stripe-Signature mismatch")


class StripeProvider(PaymentProvider):
    name = "stripe"

    def __init__(
        self,
        *,
        api_key: str,
        price_ids: dict[str, str],
        portal_return_url: str,
    ) -> None:
        self._api_key = api_key
        self._price_ids = price_ids  # plan slug -> Stripe price id
        self._portal_return_url = portal_return_url
        self._customer_cache: dict[str, str] = {}

    def create_subscription(
        self, *, user_id: UUID, plan: str, amount_cents: int, currency: str
    ) -> ProviderSubscription:
        price_id = self._price_ids.get(plan)
        if not price_id:
            raise PaymentProviderError(
                "payment_provider_error", f"No Stripe price configured for plan {plan!r}"
            )
        customer = self._ensure_customer(user_id)
        # error_if_incomplete: charge the default payment method now or fail
        # loudly — no silent 'incomplete' subscriptions on our books.
        sub = self._request(
            "POST",
            "/subscriptions",
            data={
                "customer": customer,
                "items[0][price]": price_id,
                "payment_behavior": "error_if_incomplete",
                "expand[]": "latest_invoice",
                "metadata[user_id]": str(user_id),
            },
        )
        invoice = sub.get("latest_invoice") or {}
        _log.info(
            "payment.stripe.subscribed",
            user_id=str(user_id),
            plan=plan,
            provider_subscription_id=sub["id"],
        )
        return ProviderSubscription(
            provider_subscription_id=sub["id"],
            invoice_number=invoice.get("number") or sub["id"],
            amount_cents=int(invoice.get("amount_paid") or amount_cents),
            currency=(invoice.get("currency") or currency).upper(),
        )

    def cancel_subscription(self, *, provider_subscription_id: str) -> None:
        # cancel_at_period_end mirrors our soft-cancel: Stripe stops renewing,
        # entitlement runs to period end on our side.
        self._request(
            "POST",
            f"/subscriptions/{provider_subscription_id}",
            data={"cancel_at_period_end": "true"},
        )
        _log.info(
            "payment.stripe.cancel_requested",
            provider_subscription_id=provider_subscription_id,
        )

    def add_payment_method(
        self, *, user_id: UUID, token: str
    ) -> ProviderPaymentMethod:
        customer = self._ensure_customer(user_id)
        pm = self._request(
            "POST", f"/payment_methods/{token}/attach", data={"customer": customer}
        )
        self._request(
            "POST",
            f"/customers/{customer}",
            data={"invoice_settings[default_payment_method]": pm["id"]},
        )
        card = pm.get("card") or {}
        wallet_type = (card.get("wallet") or {}).get("type")
        return ProviderPaymentMethod(
            provider_payment_method_id=pm["id"],
            kind="apple_pay" if wallet_type == "apple_pay" else "card",
            brand=card.get("brand") or "card",
            last4=card.get("last4") or "0000",
            exp_month=int(card.get("exp_month") or 0),
            exp_year=int(card.get("exp_year") or 0),
        )

    def create_portal_url(self, *, user_id: UUID) -> str:
        customer = self._ensure_customer(user_id)
        session = self._request(
            "POST",
            "/billing_portal/sessions",
            data={"customer": customer, "return_url": self._portal_return_url},
        )
        return session["url"]

    # ------------------------------------------------------------------
    # Internals
    # ------------------------------------------------------------------

    def _ensure_customer(self, user_id: UUID) -> str:
        key = str(user_id)
        cached = self._customer_cache.get(key)
        if cached:
            return cached
        found = self._request(
            "GET", "/customers/search", params={"query": f"metadata['user_id']:'{key}'"}
        )
        matches = found.get("data") or []
        if matches:
            customer_id = matches[0]["id"]
        else:
            created = self._request(
                "POST",
                "/customers",
                data={"metadata[user_id]": key},
                idempotency_key=f"drape-customer-{key}",
            )
            customer_id = created["id"]
            _log.info("payment.stripe.customer_created", user_id=key, customer=customer_id)
        self._customer_cache[key] = customer_id
        return customer_id

    def _request(
        self,
        method: str,
        path: str,
        *,
        data: dict[str, str] | None = None,
        params: dict[str, str] | None = None,
        idempotency_key: str | None = None,
    ) -> dict[str, Any]:
        headers = {"Authorization": f"Bearer {self._api_key}"}
        if idempotency_key:
            headers["Idempotency-Key"] = idempotency_key
        try:
            with httpx.Client(timeout=_TIMEOUT_S) as client:
                resp = client.request(
                    method, f"{_BASE_URL}{path}", headers=headers, data=data, params=params
                )
        except httpx.HTTPError as exc:
            _log.warning("payment.stripe.unreachable", path=path, error=str(exc))
            raise PaymentProviderError(
                "payment_provider_error", f"Stripe unreachable: {exc}"
            ) from exc
        try:
            payload: dict[str, Any] = resp.json()
        except ValueError as exc:
            raise PaymentProviderError(
                "payment_provider_error", f"Stripe returned non-JSON ({resp.status_code})"
            ) from exc
        if resp.status_code >= 400:
            error = payload.get("error") or {}
            _log.warning(
                "payment.stripe.error",
                path=path,
                status=resp.status_code,
                stripe_type=error.get("type"),
                stripe_code=error.get("code"),
            )
            # card_error = the user's problem (decline etc.) -> 402 upstream;
            # everything else is our/Stripe's problem -> 502.
            code = (
                "payment_failed"
                if error.get("type") == "card_error"
                else "payment_provider_error"
            )
            raise PaymentProviderError(
                code, error.get("message") or f"Stripe error {resp.status_code}"
            )
        return payload
