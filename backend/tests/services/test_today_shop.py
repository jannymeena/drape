"""Today's "Shop the look" (today_shop_service): the starter look's pieces,
else what today's plan or the wardrobe is missing, then pieces for today's
weather or occasion."""
from __future__ import annotations

from types import SimpleNamespace

import pytest
from sqlalchemy import select

from app.db.models import Product, WardrobeItem
from app.schemas.outfit import outfit_items_to_payload
from app.services import outfit_service, starter_wardrobe_service, today_shop_service
from tests.factories import make_catalog, make_outfit, make_today_plan, make_wardrobe_item


def _weather(condition="cloudy", feels=18.0):
    return SimpleNamespace(condition=condition, feels_like_c=feels)


def _full_wardrobe(db, user):
    """Enough of everything that the gap analysis finds nothing."""
    for category, n in (("tops", 5), ("bottoms", 4), ("shoes", 3), ("outerwear", 2)):
        for i in range(n):
            make_wardrobe_item(db, user, name=f"{category} {i}", category=category)


def _picks(db, user, weather=None):
    return today_shop_service.today_picks(db, user=user, weather=weather or _weather())


@pytest.mark.parametrize(
    ("condition", "feels", "needs"),
    [
        ("rain", 14.0, ["rain"]),
        ("thunderstorm", 8.0, ["rain", "cold"]),
        ("snow", -2.0, ["cold"]),
        ("clear", 22.0, ["sun"]),
        ("clear", 30.0, ["sun", "heat"]),
        ("cloudy", 18.0, []),
        ("clear", 12.0, []),
    ],
)
def test_weather_needs(condition, feels, needs):
    assert today_shop_service.weather_needs(_weather(condition, feels)) == needs
    assert today_shop_service.weather_needs(None) == []


def test_starter_mode_shops_todays_look(db, make_user):
    user = make_user()
    make_catalog(db)
    starter_wardrobe_service.assign(db, user=user)
    make_today_plan(db, user)
    items = db.scalars(
        select(WardrobeItem).where(WardrobeItem.user_id == user.id).limit(2)
    ).all()
    outfit = make_outfit(db, user, slot=0, day_occasion="work_day", dress_level="business")
    outfit.items = outfit_items_to_payload([outfit_service._to_outfit_item(i) for i in items])
    outfit.using_starter_wardrobe = True
    db.commit()

    shop = _picks(db, user)
    assert shop.kind == "look" and shop.title == "Shop today's look"
    assert [p.id for p in shop.products[:2]] == [i.product_id for i in items]
    assert len(shop.products) == 3  # topped up with a related piece


def test_what_todays_plan_is_missing_comes_first(db, make_user):
    user = make_user()
    make_catalog(db)
    make_today_plan(db, user)  # work
    make_wardrobe_item(db, user, name="Shirt", category="tops")  # too few to style
    shop = _picks(db, user)
    assert shop.kind == "missing" and shop.title == "To complete today's look"
    state = outfit_service.today_outfits_state(db, user=user)
    roles = [p.role for p in shop.products]
    assert roles[: len(state.missing_roles)] == state.missing_roles[:3]


def test_then_the_wardrobes_gaps(db, make_user):
    user = make_user()
    make_catalog(db)
    make_today_plan(db, user)
    items = [
        make_wardrobe_item(db, user, name="Shirt", category="tops"),
        make_wardrobe_item(db, user, name="Trousers", category="bottoms"),
    ]
    make_outfit(db, user, items=items, slot=0, day_occasion="work_day", dress_level="business")
    shop = _picks(db, user)
    assert shop.kind == "gap" and shop.title == "Missing from your wardrobe"
    gap_categories = {"tops", "bottoms", "shoes", "outerwear"}
    assert {p.category for p in shop.products} <= gap_categories
    assert len({p.category for p in shop.products}) == 3  # one per gap in turn


def test_a_full_wardrobe_gets_weather_pieces(db, make_user):
    user = make_user()
    rows = make_catalog(db)
    coat = next(p for p in rows if p.role == "outerwear" and p.gender == "women")
    coat.weather = ["rain", "cold"]
    db.commit()
    _full_wardrobe(db, user)
    shop = _picks(db, user, _weather("rain", 12.0))
    assert shop.kind == "rain" and shop.title == "For today's rain"
    assert shop.products[0].id == coat.id


def test_mild_weather_gets_the_occasions_accessories(db, make_user):
    user = make_user()
    make_catalog(db)
    _full_wardrobe(db, user)
    make_today_plan(db, user, occasion="date_dinner", dress_level="smart_casual")
    shop = _picks(db, user)
    assert shop.kind == "occasion"
    assert all(p.role == "accessory" for p in shop.products)
    assert all("date_night" in p.occasions for p in shop.products)


def test_the_row_is_stable_within_a_day(db, make_user):
    user = make_user()
    make_catalog(db)
    _full_wardrobe(db, user)
    first = [p.id for p in _picks(db, user).products]
    assert [p.id for p in _picks(db, user).products] == first
    assert first and len(first) == 3


def test_route_returns_the_picks_and_why(authed_client, db):
    make_catalog(db)
    r = authed_client.get("/api/v1/today/shop")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["kind"] in ("missing", "gap", "picks", "occasion", "rain", "sun", "cold", "heat")
    assert body["title"]
    assert 1 <= len(body["products"]) <= 3
    assert {"id", "name", "image_url", "product_url", "price_cents"} <= body["products"][0].keys()


def test_tagging_keeps_only_known_weather(db):
    row = Product(
        external_id="x", name="Mac | Black", brand="b", category="outerwear", price_cents=1,
        currency="USD", image_url="i", product_url="u", retailer="r",
    )
    from app.services import catalog_service

    catalog_service._apply_tags(row, {"role": "outerwear", "weather": ["rain", "fog", "cold"]})
    assert row.weather == ["cold", "rain"]
    catalog_service._apply_tags(row, {"role": "outerwear"})
    assert row.weather == []
