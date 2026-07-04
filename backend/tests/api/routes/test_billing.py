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
