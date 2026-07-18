"""Billing & Pro (item 8b) — subscriptions, history, payment methods.

`users.subscription_tier` remains the entitlement switch every gate reads
(require_pro, usage limits); this service is the only writer. Money movement
goes through the PaymentProvider (mock in dev, Stripe in 11c).

Cancellation is soft (CTO doc 5's 3-step flow): the client collects a reason,
shows the retention offer, then confirms. `cancel` keeps Pro until the paid
period lapses; expiry is applied lazily on read (`_expire_if_due`) so no
scheduler is needed pre-launch.
"""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Optional

import structlog
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import BillingRecord, PaymentMethod, Subscription, User
from app.services.providers.payment.base import PaymentProvider, PaymentProviderError

_log = structlog.get_logger("billing")

# plan -> (price_cents, period). CAD per the ca-central-1 market.
PLANS: dict[str, tuple[int, timedelta]] = {
    "pro_monthly": (999, timedelta(days=30)),
    "pro_yearly": (7999, timedelta(days=365)),
}

# Rendered into 402/429 payloads so the paywall has something to show.
PLAN_SUMMARY = [
    {"plan": "pro_monthly", "price_cents": 999, "currency": "CAD"},
    {"plan": "pro_yearly", "price_cents": 7999, "currency": "CAD"},
]

RETENTION_DISCOUNT_PCT = 50  # one period at half price


class BillingError(Exception):
    """Domain-level billing failure. Routes translate to 4xx."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _record(
    db: Session,
    *,
    user: User,
    description: str,
    amount_cents: int,
    currency: str = "CAD",
    invoice_number: Optional[str] = None,
) -> BillingRecord:
    row = BillingRecord(
        user_id=user.id,
        description=description,
        amount_cents=amount_cents,
        currency=currency,
        invoice_number=invoice_number,
        occurred_at=_now(),
    )
    db.add(row)
    return row


def _expire_if_due(db: Session, *, user: User, sub: Subscription) -> Subscription:
    """Lazy expiry: a canceled-at-period-end subscription whose period lapsed
    flips to canceled and drops the user back to free."""
    if (
        sub.status == "active"
        and sub.cancel_at_period_end
        and sub.current_period_end <= _now()
    ):
        sub.status = "canceled"
        user.subscription_tier = "free"
        db.commit()
        db.refresh(sub)
        _log.info("billing.expired", user_id=str(user.id))
    return sub


def get_subscription(db: Session, *, user: User) -> Optional[Subscription]:
    sub = db.scalar(select(Subscription).where(Subscription.user_id == user.id))
    if sub is None:
        return None
    return _expire_if_due(db, user=user, sub=sub)


def upgrade(
    db: Session, *, user: User, plan: str, payment: PaymentProvider
) -> Subscription:
    if plan not in PLANS:
        raise BillingError("unknown_plan", f"Unknown plan {plan!r}")
    price_cents, period = PLANS[plan]

    sub = get_subscription(db, user=user)
    if sub is not None and sub.status == "active" and not sub.cancel_at_period_end:
        raise BillingError("already_subscribed", "Already on Zoura Pro")

    try:
        result = payment.create_subscription(
            user_id=user.id,
            plan=plan,
            amount_cents=price_cents,
            currency="CAD",
            email=user.email,
        )
    except PaymentProviderError as exc:
        raise BillingError(exc.code, str(exc)) from exc
    now = _now()
    if sub is None:
        sub = Subscription(
            user_id=user.id,
            plan=plan,
            price_cents=price_cents,
            current_period_start=now,
            current_period_end=now + period,
            provider=payment.name,
            provider_subscription_id=result.provider_subscription_id,
        )
        db.add(sub)
    else:
        # Re-upgrade after cancel (either mid-period or lapsed).
        sub.plan = plan
        sub.status = "active"
        sub.price_cents = price_cents
        sub.current_period_start = now
        sub.current_period_end = now + period
        sub.cancel_at_period_end = False
        sub.canceled_at = None
        sub.cancellation_reason = None
        sub.retention_offer = "none"
        sub.provider_subscription_id = result.provider_subscription_id

    user.subscription_tier = "pro"
    _record(
        db,
        user=user,
        description=f"Zoura Pro ({'yearly' if plan == 'pro_yearly' else 'monthly'})",
        amount_cents=result.amount_cents,
        currency=result.currency,
        invoice_number=result.invoice_number,
    )
    db.commit()
    db.refresh(sub)
    _log.info("billing.upgraded", user_id=str(user.id), plan=plan)
    return sub


def cancel(
    db: Session, *, user: User, reason: Optional[str], payment: PaymentProvider | None
) -> Subscription:
    sub = get_subscription(db, user=user)
    if sub is None or sub.status != "active":
        raise BillingError("not_subscribed", "No active subscription to cancel")
    if sub.cancel_at_period_end:
        return sub  # idempotent
    if sub.provider_subscription_id:
        # payment is None only when billing is feature-disabled; still honor
        # the cancel locally so entitlement lapses at period end.
        if payment is None:
            _log.warning(
                "billing.cancel.no_provider",
                user_id=str(user.id),
                provider_subscription_id=sub.provider_subscription_id,
            )
        else:
            try:
                payment.cancel_subscription(
                    provider_subscription_id=sub.provider_subscription_id
                )
            except PaymentProviderError as exc:
                raise BillingError(exc.code, str(exc)) from exc
    sub.cancel_at_period_end = True
    sub.canceled_at = _now()
    sub.cancellation_reason = reason
    sub.retention_offer = "offered"
    db.commit()
    db.refresh(sub)
    _log.info("billing.cancel_requested", user_id=str(user.id), reason=reason)
    return sub


def accept_retention_offer(db: Session, *, user: User) -> Subscription:
    """Un-cancels and credits one period at RETENTION_DISCOUNT_PCT off."""
    sub = get_subscription(db, user=user)
    if sub is None or not sub.cancel_at_period_end or sub.status != "active":
        raise BillingError(
            "no_offer", "Retention offer applies only to a pending cancellation"
        )
    sub.cancel_at_period_end = False
    sub.canceled_at = None
    sub.retention_offer = "accepted"
    discounted = sub.price_cents * (100 - RETENTION_DISCOUNT_PCT) // 100
    _record(
        db,
        user=user,
        description=f"Retention offer — {RETENTION_DISCOUNT_PCT}% off next period",
        amount_cents=discounted - sub.price_cents,  # negative = credit
    )
    db.commit()
    db.refresh(sub)
    _log.info("billing.retention_accepted", user_id=str(user.id))
    return sub


def billing_history(db: Session, *, user: User) -> list[BillingRecord]:
    return list(
        db.scalars(
            select(BillingRecord)
            .where(BillingRecord.user_id == user.id)
            .order_by(BillingRecord.occurred_at.desc())
        ).all()
    )


def list_payment_methods(db: Session, *, user: User) -> list[PaymentMethod]:
    return list(
        db.scalars(
            select(PaymentMethod)
            .where(PaymentMethod.user_id == user.id)
            .order_by(PaymentMethod.is_default.desc(), PaymentMethod.created_at)
        ).all()
    )


def add_payment_method(
    db: Session, *, user: User, token: str, payment: PaymentProvider
) -> PaymentMethod:
    try:
        result = payment.add_payment_method(
            user_id=user.id, token=token, email=user.email
        )
    except PaymentProviderError as exc:
        raise BillingError(exc.code, str(exc)) from exc
    first = not list_payment_methods(db, user=user)
    row = PaymentMethod(
        user_id=user.id,
        kind=result.kind,
        brand=result.brand,
        last4=result.last4,
        exp_month=result.exp_month,
        exp_year=result.exp_year,
        is_default=first,
        provider_payment_method_id=result.provider_payment_method_id,
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return row


def portal_url(*, user: User, payment: PaymentProvider) -> str:
    try:
        return payment.create_portal_url(user_id=user.id, email=user.email)
    except PaymentProviderError as exc:
        raise BillingError(exc.code, str(exc)) from exc


# ---------------------------------------------------------------------------
# Stripe webhook (signature already verified by the route)
# ---------------------------------------------------------------------------


def _from_epoch(value) -> Optional[datetime]:
    return datetime.fromtimestamp(value, tz=timezone.utc) if value else None


def _sub_by_provider_id(db: Session, provider_subscription_id: str) -> Optional[Subscription]:
    return db.scalar(
        select(Subscription).where(
            Subscription.provider_subscription_id == provider_subscription_id
        )
    )


def apply_stripe_event(db: Session, *, event: dict) -> str:
    """Apply one verified Stripe event; returns an outcome slug for logging.

    Unknown event types and unknown subscription ids are acknowledged, not
    errors — Stripe retries anything that isn't answered 2xx.
    """
    event_type = event.get("type", "")
    obj = (event.get("data") or {}).get("object") or {}

    if event_type == "invoice.paid":
        if obj.get("billing_reason") == "subscription_create":
            return "ignored"  # first charge is recorded synchronously by upgrade()
        sub = _sub_by_provider_id(db, obj.get("subscription") or "")
        if sub is None:
            _log.warning("billing.webhook.unknown_subscription", event_type=event_type)
            return "unknown_subscription"
        user = db.get(User, sub.user_id)
        lines = (obj.get("lines") or {}).get("data") or [{}]
        period = lines[0].get("period") or {}
        now = _now()
        sub.status = "active"
        sub.current_period_start = _from_epoch(period.get("start")) or now
        sub.current_period_end = _from_epoch(period.get("end")) or (
            now + PLANS[sub.plan][1]
        )
        user.subscription_tier = "pro"
        _record(
            db,
            user=user,
            description=f"Zoura Pro renewal ({'yearly' if sub.plan == 'pro_yearly' else 'monthly'})",
            amount_cents=int(obj.get("amount_paid") or sub.price_cents),
            currency=(obj.get("currency") or "cad").upper(),
            invoice_number=obj.get("number"),
        )
        db.commit()
        _log.info("billing.webhook.renewed", user_id=str(user.id))
        return "renewed"

    if event_type == "invoice.payment_failed":
        sub = _sub_by_provider_id(db, obj.get("subscription") or "")
        if sub is None:
            return "unknown_subscription"
        user = db.get(User, sub.user_id)
        # Entitlement is NOT flipped here: Stripe retries the charge, and a
        # terminal failure arrives as customer.subscription.deleted.
        row = _record(
            db,
            user=user,
            description="Zoura Pro renewal — payment failed",
            amount_cents=int(obj.get("amount_due") or sub.price_cents),
            currency=(obj.get("currency") or "cad").upper(),
            invoice_number=obj.get("number"),
        )
        row.status = "failed"
        db.commit()
        _log.warning("billing.webhook.payment_failed", user_id=str(user.id))
        return "payment_failed_recorded"

    if event_type == "customer.subscription.deleted":
        sub = _sub_by_provider_id(db, obj.get("id") or "")
        if sub is None:
            return "unknown_subscription"
        user = db.get(User, sub.user_id)
        sub.status = "canceled"
        user.subscription_tier = "free"
        db.commit()
        _log.info("billing.webhook.subscription_deleted", user_id=str(user.id))
        return "canceled"

    return "ignored"
