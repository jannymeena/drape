"""Starter wardrobe route tests — template listing, assignment idempotency,
manual deactivation, auto-deactivation at 15 real items."""
from __future__ import annotations

from sqlalchemy import select

from app.db.models import UserStarterWardrobe, WardrobeItem
from tests.factories import make_wardrobe_item


def test_list_templates_returns_seeded_templates(authed_client):
    """The squashed init migration seeds 6 templates from JSON. Listing must
    return at least those 6 — the migration is the source of truth."""
    r = authed_client.get("/api/v1/starter-wardrobe/templates")
    assert r.status_code == 200
    templates = r.json()["templates"]
    assert len(templates) >= 6
    # Sanity-check one shape: each template has template_id + name + items.
    sample = templates[0]
    assert sample["template_id"]
    assert sample["name"]
    assert sample["items"]


def test_assign_materializes_items_into_wardrobe(authed_client, db):
    r = authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["items_materialized"] >= 1
    assert body["swapped"] is True

    # Confirm rows actually landed in wardrobe_items with the starter flag.
    starter_count = (
        db.query(WardrobeItem)
        .filter(
            WardrobeItem.user_id == authed_client.test_user.id,
            WardrobeItem.is_starter_wardrobe.is_(True),
        )
        .count()
    )
    assert starter_count == body["items_materialized"]


def test_assign_idempotent_when_user_has_real_items(authed_client, db):
    """First assign materializes; once the user has any real item, a re-assign
    must be a no-op (else we'd silently delete items the user ranked or wore)."""
    authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    # Add 1 real item.
    make_wardrobe_item(db, authed_client.test_user, name="Real", is_starter_wardrobe=False)
    # Re-assign should not swap.
    r = authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    assert r.status_code == 200
    body = r.json()
    assert body["items_materialized"] == 0
    assert body["swapped"] is False


def test_deactivate_marks_assignment_inactive(authed_client, db):
    authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    r = authed_client.post(
        "/api/v1/starter-wardrobe/deactivate", json={"reason": "manual"}
    )
    assert r.status_code == 200
    assert r.json()["assignment"]["is_active"] is False


def test_deactivate_idempotent_on_already_inactive(authed_client):
    authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    r1 = authed_client.post("/api/v1/starter-wardrobe/deactivate", json={"reason": "manual"})
    r2 = authed_client.post("/api/v1/starter-wardrobe/deactivate", json={"reason": "manual"})
    # Both succeed; second is a no-op (returns the same row).
    assert r1.status_code == 200
    assert r2.status_code == 200
    assert r2.json()["assignment"]["is_active"] is False


def test_deactivate_without_assignment_returns_404(authed_client):
    """User who never had a starter wardrobe → can't deactivate one."""
    r = authed_client.post(
        "/api/v1/starter-wardrobe/deactivate", json={"reason": "manual"}
    )
    assert r.status_code == 404


def test_auto_deactivate_when_user_reaches_15_real_items(authed_client, db):
    """recompute_transition (called by `wardrobe_service.create_item`) flips
    is_active=false once real items ≥ 15. Going through the API exercises the
    full hook chain; using `make_wardrobe_item` directly would bypass it."""
    authed_client.post("/api/v1/starter-wardrobe/assign", json={})

    # Add 15 real items via the API so each create fires recompute_transition.
    for i in range(15):
        r = authed_client.post(
            "/api/v1/wardrobe/items",
            json={"name": f"Real {i}", "category": "tops"},
        )
        assert r.status_code == 201, r.text

    user = authed_client.test_user
    assignment = db.scalar(
        select(UserStarterWardrobe).where(UserStarterWardrobe.user_id == user.id)
    )
    assert assignment is not None
    db.refresh(assignment)
    assert assignment.is_active is False
    assert assignment.deactivation_reason == "user_has_enough_items"
