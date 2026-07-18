"""Billing routes (item 8b) — subscription lifecycle, history, payment methods.

The 3-step cancellation (CTO doc 5): client collects a reason -> POST
/subscription/cancel (soft; Pro runs to period end, retention offer becomes
available) -> either POST /subscription/retention-offer/accept (un-cancel +
discount credit) or nothing (lazy expiry drops the user to free).
"""
from __future__ import annotations

import json

from fastapi import APIRouter, Depends, HTTPException, Request, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.providers import get_payment_provider
from app.core.config import settings
from app.db.models import Subscription, User
from app.db.session import get_db
from app.schemas.billing import (
    AddPaymentMethodRequest,
    BillingHistoryResponse,
    BillingRecordResponse,
    CancelRequest,
    PaymentMethodListResponse,
    PaymentMethodResponse,
    PlanSummary,
    PortalResponse,
    SubscriptionResponse,
    UpgradeRequest,
)
from app.services import billing_service
from app.services.billing_service import PLAN_SUMMARY, BillingError
from app.services.providers.payment.base import PaymentProvider, PaymentProviderError
from app.services.providers.payment.stripe import verify_webhook_signature

router = APIRouter(tags=["billing"])

_PLANS = [PlanSummary(**p) for p in PLAN_SUMMARY]


def _translate(err: BillingError) -> HTTPException:
    code = {
        "unknown_plan": status.HTTP_422_UNPROCESSABLE_ENTITY,
        "already_subscribed": status.HTTP_409_CONFLICT,
        "not_subscribed": status.HTTP_404_NOT_FOUND,
        "no_offer": status.HTTP_409_CONFLICT,
        "payment_failed": status.HTTP_402_PAYMENT_REQUIRED,
        "payment_provider_error": status.HTTP_502_BAD_GATEWAY,
    }.get(err.code, status.HTTP_400_BAD_REQUEST)
    return HTTPException(status_code=code, detail={"error": err.code, "message": str(err)})


def _require_payment(payment: PaymentProvider | None) -> PaymentProvider:
    """Billing is feature-disabled (DISABLED_FEATURES=billing) when None."""
    if payment is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "billing_unavailable", "message": "Billing not enabled in this environment"},
        )
    return payment


def _to_response(user: User, sub: Subscription | None) -> SubscriptionResponse:
    if sub is None or sub.status != "active":
        return SubscriptionResponse(tier="free", plans=_PLANS)
    return SubscriptionResponse(
        tier="pro",
        plan=sub.plan,
        status=sub.status,
        price_cents=sub.price_cents,
        currency=sub.currency,
        current_period_start=sub.current_period_start,
        current_period_end=sub.current_period_end,
        cancel_at_period_end=sub.cancel_at_period_end,
        retention_offer=sub.retention_offer,
        plans=_PLANS,
    )


@router.get("/subscription", response_model=SubscriptionResponse)
def get_subscription(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SubscriptionResponse:
    return _to_response(user, billing_service.get_subscription(db, user=user))


@router.post("/subscription/upgrade", response_model=SubscriptionResponse)
def upgrade(
    payload: UpgradeRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    payment: PaymentProvider | None = Depends(get_payment_provider),
) -> SubscriptionResponse:
    try:
        sub = billing_service.upgrade(
            db, user=user, plan=payload.plan, payment=_require_payment(payment)
        )
    except BillingError as err:
        raise _translate(err) from err
    return _to_response(user, sub)


@router.post("/subscription/cancel", response_model=SubscriptionResponse)
def cancel(
    payload: CancelRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    payment: PaymentProvider | None = Depends(get_payment_provider),
) -> SubscriptionResponse:
    try:
        sub = billing_service.cancel(
            db, user=user, reason=payload.reason, payment=payment
        )
    except BillingError as err:
        raise _translate(err) from err
    return _to_response(user, sub)


@router.post("/subscription/retention-offer/accept", response_model=SubscriptionResponse)
def accept_retention_offer(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SubscriptionResponse:
    try:
        sub = billing_service.accept_retention_offer(db, user=user)
    except BillingError as err:
        raise _translate(err) from err
    return _to_response(user, sub)


@router.get("/billing/history", response_model=BillingHistoryResponse)
def billing_history(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> BillingHistoryResponse:
    records = billing_service.billing_history(db, user=user)
    return BillingHistoryResponse(
        records=[BillingRecordResponse.model_validate(r) for r in records]
    )


@router.get("/payment-methods", response_model=PaymentMethodListResponse)
def list_payment_methods(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> PaymentMethodListResponse:
    methods = billing_service.list_payment_methods(db, user=user)
    return PaymentMethodListResponse(
        methods=[PaymentMethodResponse.model_validate(m) for m in methods]
    )


@router.post(
    "/payment-methods",
    response_model=PaymentMethodResponse,
    status_code=status.HTTP_201_CREATED,
)
def add_payment_method(
    payload: AddPaymentMethodRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    payment: PaymentProvider | None = Depends(get_payment_provider),
) -> PaymentMethodResponse:
    try:
        method = billing_service.add_payment_method(
            db, user=user, token=payload.token, payment=_require_payment(payment)
        )
    except BillingError as err:
        raise _translate(err) from err
    return PaymentMethodResponse.model_validate(method)


@router.post("/billing/portal", response_model=PortalResponse)
def billing_portal(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    payment: PaymentProvider | None = Depends(get_payment_provider),
) -> PortalResponse:
    try:
        url = billing_service.portal_url(
            db, user=user, payment=_require_payment(payment)
        )
    except BillingError as err:
        raise _translate(err) from err
    return PortalResponse(url=url)


@router.post("/billing/webhook/stripe")
async def stripe_webhook(
    request: Request,
    db: Session = Depends(get_db),
) -> dict:
    """Unauthenticated by design — Stripe calls it; the HMAC signature is the auth."""
    secret = settings.stripe_webhook_secret
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "billing_unavailable", "message": "Stripe webhook not configured"},
        )
    payload = await request.body()
    try:
        verify_webhook_signature(
            payload, request.headers.get("stripe-signature", ""), secret
        )
    except PaymentProviderError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "invalid_signature", "message": str(exc)},
        ) from exc
    try:
        event = json.loads(payload)
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": "invalid_payload", "message": "Body is not valid JSON"},
        ) from exc
    outcome = billing_service.apply_stripe_event(db, event=event)
    return {"received": True, "outcome": outcome}
