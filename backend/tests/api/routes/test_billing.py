"""Billing routes (2.2, item 8b) — the full mock-provider lifecycle:
upgrade flips the Pro gate open, soft-cancel keeps Pro until period end,
retention offer un-cancels, lazy expiry drops back to free."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from app.db.models import Subscription


def test_subscription_defaults_to_free_with_plans(authed_client):
    r = authed_client.get("/api/v1/subscription")
    assert r.status_code == 200
    body = r.json()
    assert body["tier"] == "free"
    assert {p["plan"] for p in body["plans"]} == {"pro_monthly", "pro_yearly"}


def test_upgrade_flips_pro_and_opens_gates(authed_client):
    # Pro-gated endpoint 402s while free — and the payload carries the plans.
    r = authed_client.get("/api/v1/wardrobe/analytics/intelligence-report")
    assert r.status_code == 402
    assert r.json()["detail"]["plans"]

    r = authed_client.post(
        "/api/v1/subscription/upgrade", json={"plan": "pro_monthly"}
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["tier"] == "pro"
    assert body["plan"] == "pro_monthly"

    # Gate opens.
    r = authed_client.get("/api/v1/wardrobe/analytics/intelligence-report")
    assert r.status_code == 200

    # Charge landed in history.
    r = authed_client.get("/api/v1/billing/history")
    records = r.json()["records"]
    assert len(records) == 1
    assert records[0]["amount_cents"] == 999
    assert records[0]["invoice_number"].startswith("INV-")


def test_double_upgrade_409(authed_client):
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    r = authed_client.post(
        "/api/v1/subscription/upgrade", json={"plan": "pro_yearly"}
    )
    assert r.status_code == 409


def test_cancel_keeps_pro_until_period_end(authed_client):
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    r = authed_client.post(
        "/api/v1/subscription/cancel", json={"reason": "too expensive"}
    )
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["tier"] == "pro"  # still pro until the paid period lapses
    assert body["cancel_at_period_end"] is True
    assert body["retention_offer"] == "offered"

    # Pro gate still open mid-period.
    r = authed_client.get("/api/v1/wardrobe/analytics/intelligence-report")
    assert r.status_code == 200


def test_cancel_without_subscription_404(authed_client):
    r = authed_client.post("/api/v1/subscription/cancel", json={})
    assert r.status_code == 404


def test_retention_offer_uncancels_and_credits(authed_client):
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    authed_client.post("/api/v1/subscription/cancel", json={"reason": "meh"})

    r = authed_client.post("/api/v1/subscription/retention-offer/accept")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["cancel_at_period_end"] is False
    assert body["retention_offer"] == "accepted"

    # The 50%-off credit shows in history as a negative amount.
    records = authed_client.get("/api/v1/billing/history").json()["records"]
    credits = [x for x in records if x["amount_cents"] < 0]
    assert len(credits) == 1


def test_retention_offer_without_pending_cancel_409(authed_client):
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    r = authed_client.post("/api/v1/subscription/retention-offer/accept")
    assert r.status_code == 409


def test_lazy_expiry_drops_to_free(authed_client, db):
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    authed_client.post("/api/v1/subscription/cancel", json={"reason": "bye"})
    # Rewind the paid period so it has lapsed.
    sub = db.scalar(
        select(Subscription).where(
            Subscription.user_id == authed_client.test_user.id
        )
    )
    sub.current_period_end = datetime.now(timezone.utc) - timedelta(seconds=1)
    db.commit()

    r = authed_client.get("/api/v1/subscription")
    assert r.json()["tier"] == "free"
    # Gate closes again.
    r = authed_client.get("/api/v1/wardrobe/analytics/intelligence-report")
    assert r.status_code == 402


def test_reupgrade_after_lapse(authed_client, db):
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    authed_client.post("/api/v1/subscription/cancel", json={})
    sub = db.scalar(
        select(Subscription).where(
            Subscription.user_id == authed_client.test_user.id
        )
    )
    sub.current_period_end = datetime.now(timezone.utc) - timedelta(seconds=1)
    db.commit()
    authed_client.get("/api/v1/subscription")  # trigger lazy expiry

    r = authed_client.post(
        "/api/v1/subscription/upgrade", json={"plan": "pro_yearly"}
    )
    assert r.status_code == 200, r.text
    assert r.json()["plan"] == "pro_yearly"


def test_payment_methods_add_and_list(authed_client):
    r = authed_client.post(
        "/api/v1/payment-methods", json={"token": "tok_4242424242424242"}
    )
    assert r.status_code == 201, r.text
    body = r.json()
    assert body["brand"] == "visa"
    assert body["last4"] == "4242"
    assert body["is_default"] is True  # first method becomes default

    authed_client.post("/api/v1/payment-methods", json={"token": "tok_x"})
    methods = authed_client.get("/api/v1/payment-methods").json()["methods"]
    assert len(methods) == 2
    assert sum(1 for m in methods if m["is_default"]) == 1


# ---------------------------------------------------------------------------
# Portal + billing feature switch
# ---------------------------------------------------------------------------

import hashlib
import hmac
import json as jsonlib
import time

from app.api.dependencies.providers import get_payment_provider
from app.core.config import settings
from app.main import app


def test_billing_portal_returns_url(authed_client):
    r = authed_client.post("/api/v1/billing/portal")
    assert r.status_code == 200, r.text
    assert r.json()["url"].startswith("https://")


def test_billing_disabled_answers_400(authed_client):
    # Simulates DISABLED_FEATURES=billing in tbd/prd (container wires None).
    app.dependency_overrides[get_payment_provider] = lambda: None
    for call in (
        lambda: authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"}),
        lambda: authed_client.post("/api/v1/payment-methods", json={"token": "tok_x"}),
        lambda: authed_client.post("/api/v1/billing/portal"),
    ):
        r = call()
        assert r.status_code == 400, r.text
        assert r.json()["detail"]["code"] == "billing_unavailable"


# ---------------------------------------------------------------------------
# Stripe webhook
# ---------------------------------------------------------------------------

_WEBHOOK_SECRET = "whsec_test"
_WEBHOOK_PATH = "/api/v1/billing/webhook/stripe"


def _signed_post(client, event: dict, *, secret: str = _WEBHOOK_SECRET):
    payload = jsonlib.dumps(event).encode()
    ts = int(time.time())
    mac = hmac.new(secret.encode(), f"{ts}.".encode() + payload, hashlib.sha256).hexdigest()
    return client.post(
        _WEBHOOK_PATH,
        content=payload,
        headers={"stripe-signature": f"t={ts},v1={mac}", "content-type": "application/json"},
    )


def _provider_sub_id(db, user) -> str:
    sub = db.scalar(select(Subscription).where(Subscription.user_id == user.id))
    return sub.provider_subscription_id


def test_webhook_unconfigured_answers_400(authed_client):
    r = authed_client.post(_WEBHOOK_PATH, content=b"{}")
    assert r.status_code == 400
    assert r.json()["detail"]["code"] == "billing_unavailable"


def test_webhook_bad_signature_rejected(authed_client, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", _WEBHOOK_SECRET)
    r = authed_client.post(
        _WEBHOOK_PATH, content=b"{}", headers={"stripe-signature": "t=1,v1=deadbeef"}
    )
    assert r.status_code == 400
    assert r.json()["detail"]["code"] == "invalid_signature"


def test_webhook_renewal_extends_period_and_records_charge(authed_client, db, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", _WEBHOOK_SECRET)
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    sub_id = _provider_sub_id(db, authed_client.test_user)

    period_start = int(time.time())
    period_end = period_start + 30 * 86400
    r = _signed_post(
        authed_client,
        {
            "type": "invoice.paid",
            "data": {
                "object": {
                    "billing_reason": "subscription_cycle",
                    "subscription": sub_id,
                    "amount_paid": 999,
                    "currency": "cad",
                    "number": "INV-RENEW-1",
                    "lines": {"data": [{"period": {"start": period_start, "end": period_end}}]},
                }
            },
        },
    )
    assert r.status_code == 200, r.text
    assert r.json()["outcome"] == "renewed"

    db.expire_all()
    sub = db.scalar(
        select(Subscription).where(Subscription.user_id == authed_client.test_user.id)
    )
    assert int(sub.current_period_end.timestamp()) == period_end

    records = authed_client.get("/api/v1/billing/history").json()["records"]
    assert len(records) == 2  # initial charge + renewal
    assert records[0]["invoice_number"] == "INV-RENEW-1"


def test_webhook_first_invoice_not_double_recorded(authed_client, db, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", _WEBHOOK_SECRET)
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    sub_id = _provider_sub_id(db, authed_client.test_user)

    r = _signed_post(
        authed_client,
        {
            "type": "invoice.paid",
            "data": {"object": {"billing_reason": "subscription_create", "subscription": sub_id}},
        },
    )
    assert r.json()["outcome"] == "ignored"
    records = authed_client.get("/api/v1/billing/history").json()["records"]
    assert len(records) == 1  # only the synchronous upgrade charge


def test_webhook_subscription_deleted_drops_to_free(authed_client, db, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", _WEBHOOK_SECRET)
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    sub_id = _provider_sub_id(db, authed_client.test_user)

    r = _signed_post(
        authed_client,
        {"type": "customer.subscription.deleted", "data": {"object": {"id": sub_id}}},
    )
    assert r.status_code == 200
    assert r.json()["outcome"] == "canceled"

    assert authed_client.get("/api/v1/subscription").json()["tier"] == "free"
    # Pro gate closes.
    r = authed_client.get("/api/v1/wardrobe/analytics/intelligence-report")
    assert r.status_code == 402


def test_webhook_payment_failed_records_but_keeps_entitlement(authed_client, db, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", _WEBHOOK_SECRET)
    authed_client.post("/api/v1/subscription/upgrade", json={"plan": "pro_monthly"})
    sub_id = _provider_sub_id(db, authed_client.test_user)

    r = _signed_post(
        authed_client,
        {
            "type": "invoice.payment_failed",
            "data": {"object": {"subscription": sub_id, "amount_due": 999, "currency": "cad"}},
        },
    )
    assert r.json()["outcome"] == "payment_failed_recorded"
    # Stripe retries; entitlement survives until customer.subscription.deleted.
    assert authed_client.get("/api/v1/subscription").json()["tier"] == "pro"
    records = authed_client.get("/api/v1/billing/history").json()["records"]
    assert any(rec["status"] == "failed" for rec in records)


def test_webhook_unknown_subscription_acknowledged(authed_client, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", _WEBHOOK_SECRET)
    r = _signed_post(
        authed_client,
        {"type": "customer.subscription.deleted", "data": {"object": {"id": "sub_nope"}}},
    )
    # 2xx so Stripe stops retrying; the mismatch is only logged.
    assert r.status_code == 200
    assert r.json()["outcome"] == "unknown_subscription"


def test_webhook_unhandled_event_ignored(authed_client, monkeypatch):
    monkeypatch.setattr(settings, "stripe_webhook_secret", _WEBHOOK_SECRET)
    r = _signed_post(authed_client, {"type": "charge.refunded", "data": {"object": {}}})
    assert r.status_code == 200
    assert r.json()["outcome"] == "ignored"
