"""Starter wardrobe tests — the whole tagged catalog for the user's genders
(product links, occasions), keeping in step with the catalog (`refresh`),
idempotency, manual deactivation, and auto-deactivation at the threshold
the client counts down to."""
from __future__ import annotations

import pytest
from sqlalchemy import select

from app.db.models import Product, UserStarterWardrobe, WardrobeItem
from app.services import starter_wardrobe_service
from tests.factories import make_catalog, make_wardrobe_item


@pytest.fixture(autouse=True)
def _catalog(db):
    make_catalog(db)


def _set_style(db, user, style):
    user.shopping_style = style
    db.add(user)
    db.commit()


def _starter_items(db, user) -> list[WardrobeItem]:
    return list(
        db.scalars(
            select(WardrobeItem).where(
                WardrobeItem.user_id == user.id, WardrobeItem.is_starter_wardrobe.is_(True)
            )
        ).all()
    )


def _tagged(db, gender):
    return [
        p
        for p in db.scalars(select(Product)).all()
        if p.gender == gender and p.is_active and p.tagged_at is not None
    ]


def test_womens_starter_is_every_womens_product(authed_client, db):
    user = authed_client.test_user
    _set_style(db, user, "womens")
    r = authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    assert r.status_code == 200, r.text
    assert r.json()["template_id"] == "awin_capsule"

    items = _starter_items(db, user)
    womens = _tagged(db, "women")
    assert {i.product_id for i in items} == {p.id for p in womens}
    # Starter items carry the product's image, cleaned name, occasions and
    # buy link.
    products = {p.id: p for p in womens}
    item = items[0]
    assert item.primary_image_url == products[item.product_id].image_url
    assert item.occasions == products[item.product_id].occasions
    assert "|" not in item.name
    listed = authed_client.get("/api/v1/wardrobe?limit=100").json()["items"]
    assert all(i["product_url"].startswith("https://www.awin1.com/") for i in listed)


def test_mens_starter_is_every_mens_product(authed_client, db):
    user = authed_client.test_user
    _set_style(db, user, "mens")
    assert authed_client.post("/api/v1/starter-wardrobe/assign", json={}).status_code == 200
    items = _starter_items(db, user)
    assert {i.product_id for i in items} == {p.id for p in _tagged(db, "men")}
    assert {i.category for i in items} == {"tops", "bottoms", "outerwear", "accessories"}


def test_both_gets_both_catalogs(authed_client, db):
    _set_style(db, authed_client.test_user, "both")
    authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    assert len(_starter_items(db, authed_client.test_user)) == len(_tagged(db, "women")) + len(
        _tagged(db, "men")
    )


def test_refresh_follows_the_catalog(authed_client, db):
    user = authed_client.test_user
    _set_style(db, user, "mens")
    authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    mens = _tagged(db, "men")
    gone, retagged = mens[0], mens[1]
    gone.is_active = False  # the feed dropped it
    retagged.occasions = ["gym"]
    new = Product(
        external_id="awin_men_new", name="New Tee | White", brand="boohoo", category="tops",
        price_cents=1500, currency="USD", image_url="https://img.example/new.jpg",
        product_url="https://www.awin1.com/pclick.php?p=new", retailer="boohoo men",
        gender="men", role="top", warmth="mid", formality="casual", occasions=["casual"],
        color_name="white", tagged_at=gone.tagged_at,
    )
    untagged = Product(
        external_id="awin_men_untagged", name="Untagged Tee", brand="boohoo", category="tops",
        price_cents=1500, currency="USD", image_url="https://img.example/u.jpg",
        product_url="https://www.awin1.com/pclick.php?p=u", retailer="boohoo men", gender="men",
    )
    db.add_all([new, untagged])
    db.commit()

    assert starter_wardrobe_service.refresh_all(db) == 1
    by_product = {i.product_id: i for i in _starter_items(db, user)}
    assert gone.id not in by_product
    assert new.id in by_product and untagged.id not in by_product
    assert by_product[retagged.id].occasions == ["gym"]


def test_refresh_leaves_an_inactive_starter_alone(authed_client, db):
    user = authed_client.test_user
    authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    before = len(_starter_items(db, user))
    authed_client.post("/api/v1/starter-wardrobe/deactivate", json={"reason": "manual"})
    db.query(Product).update({Product.is_active: False})
    db.commit()
    assert starter_wardrobe_service.refresh(db, user=user) == (0, 0)
    assert len(_starter_items(db, user)) == before


def test_assign_503_until_products_are_tagged(authed_client, db):
    db.query(Product).update({Product.tagged_at: None})
    db.commit()
    r = authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    assert r.status_code == 503
    assert _starter_items(db, authed_client.test_user) == []


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


def test_auto_deactivate_at_the_threshold_the_app_promises(authed_client, db):
    """recompute_transition (called by `wardrobe_service.create_item`) flips
    is_active=false once real items reach AUTO_DEACTIVATE_REAL_ITEMS. Going
    through the API exercises the full hook chain; using `make_wardrobe_item`
    directly would bypass it.

    Regression: this used to be 15 while the client banner counted down to 10
    ("n/10 ITEMS TO UNLOCK REAL WARDROBE MODE") and `_blend_pool` switched to
    real-only at 10 — so a user who hit the number the UI asked for kept their
    starter wardrobe anyway.
    """
    assert starter_wardrobe_service.AUTO_DEACTIVATE_REAL_ITEMS == 10

    authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    user = authed_client.test_user

    def assignment():
        row = db.scalar(
            select(UserStarterWardrobe).where(UserStarterWardrobe.user_id == user.id)
        )
        db.refresh(row)
        return row

    for i in range(starter_wardrobe_service.AUTO_DEACTIVATE_REAL_ITEMS - 1):
        r = authed_client.post(
            "/api/v1/wardrobe/items",
            json={"name": f"Real {i}", "category": "tops"},
        )
        assert r.status_code == 201, r.text
    # One short: still active, so the banner still has something to count.
    assert assignment().is_active is True

    r = authed_client.post(
        "/api/v1/wardrobe/items", json={"name": "Real last", "category": "tops"}
    )
    assert r.status_code == 201, r.text

    assert assignment().is_active is False
    assert assignment().deactivation_reason == "user_has_enough_items"


def test_retired_starter_items_drop_out_of_the_wardrobe(authed_client):
    """Doc 3 §Banner States 3: once the starter wardrobe retires the user
    "sees 100% real wardrobe". The rows are kept, but the default listing
    stops returning them."""
    authed_client.post("/api/v1/starter-wardrobe/assign", json={})

    listed = authed_client.get("/api/v1/wardrobe?limit=100").json()
    assert any(i["is_starter_wardrobe"] for i in listed["items"]), (
        "precondition: starter items are visible while the kit is active"
    )

    authed_client.post("/api/v1/starter-wardrobe/deactivate", json={})

    listed = authed_client.get("/api/v1/wardrobe?limit=100").json()
    assert listed["items"] == [] or not any(
        i["is_starter_wardrobe"] for i in listed["items"]
    )
    # The count has to agree with the page, or pagination reports phantoms.
    assert listed["total"] == len(listed["items"])


def test_retired_starter_items_are_still_reachable_when_asked_for(authed_client):
    """Hidden by default, not deleted — an explicit filter still returns them,
    so the transition screens and any audit path keep working."""
    authed_client.post("/api/v1/starter-wardrobe/assign", json={})
    authed_client.post("/api/v1/starter-wardrobe/deactivate", json={})

    listed = authed_client.get(
        "/api/v1/wardrobe?limit=100&is_starter_wardrobe=true"
    ).json()
    assert listed["total"] > 0
    assert all(i["is_starter_wardrobe"] for i in listed["items"])
