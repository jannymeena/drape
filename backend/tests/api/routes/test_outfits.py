"""Outfits + Today route tests — ports the bash 05_today.sh and 06_outfits.sh
checks with structured assertions. Exercises the CannedAIProvider's chat()
path end-to-end (the only file that does — wardrobe tests use analyze_image).

Test groups:
  * dashboard / generate
  * reasoning
  * regenerate
  * mix-and-match (deterministic — no AI roundtrip)
  * log + streak + toasts
  * history
"""
from __future__ import annotations

from datetime import date, timedelta

import pytest
from sqlalchemy import select

from app.db.models import Outfit, StreakTracking
from tests.factories import make_outfit, make_starter_wardrobe


# ---------------------------------------------------------------------------
# /today/dashboard
# ---------------------------------------------------------------------------


def test_dashboard_with_empty_wardrobe_returns_400(authed_client):
    r = authed_client.get("/api/v1/today/dashboard")
    assert r.status_code == 400, r.text
    assert "wardrobe" in r.text.lower()


def test_dashboard_with_starter_wardrobe_returns_3_outfits(authed_client, db):
    make_starter_wardrobe(db, authed_client.test_user, count=9)
    r = authed_client.get("/api/v1/today/dashboard")
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["outfits"]) == 3
    assert body["banners"]["starter_wardrobe"] is True
    # Every item id in every outfit must come from this user's wardrobe.
    user_item_ids = {
        str(i.id)
        for i in db.query(__import__("app.db.models", fromlist=["WardrobeItem"]).WardrobeItem)
        .filter_by(user_id=authed_client.test_user.id)
        .all()
    }
    for outfit in body["outfits"]:
        for it in outfit["items"]:
            assert it["item_id"] in user_item_ids


def test_dashboard_caches_today_outfits_across_reads(authed_client, db):
    """Second call returns the same SET of outfits as the first — the route
    short-circuits when ≥3 outfits exist for today. We don't assert order
    because the service doesn't promise it (created_at can collide at the
    microsecond and `ORDER BY created_at DESC` has no tie-breaker)."""
    make_starter_wardrobe(db, authed_client.test_user, count=9)
    first = authed_client.get("/api/v1/today/dashboard").json()
    second = authed_client.get("/api/v1/today/dashboard").json()
    assert {o["id"] for o in first["outfits"]} == {o["id"] for o in second["outfits"]}


def test_dashboard_outfit_image_url_is_null(authed_client, db):
    """Decision #2: server doesn't render flat-lay composites."""
    make_starter_wardrobe(db, authed_client.test_user, count=9)
    body = authed_client.get("/api/v1/today/dashboard").json()
    assert all(o["image_url"] is None for o in body["outfits"])


# ---------------------------------------------------------------------------
# /today/generate-outfits
# ---------------------------------------------------------------------------


def test_generate_force_creates_outfits_with_requested_occasion(authed_client, db):
    make_starter_wardrobe(db, authed_client.test_user, count=9)
    r = authed_client.post("/api/v1/today/generate-outfits", json={"occasions": ["gym"]})
    assert r.status_code == 200, r.text
    body = r.json()
    assert len(body["outfits"]) == 1
    assert body["outfits"][0]["occasion"] == "gym"


def test_generate_with_no_wardrobe_returns_400(authed_client):
    r = authed_client.post("/api/v1/today/generate-outfits", json={"occasions": ["work"]})
    assert r.status_code == 400


# ---------------------------------------------------------------------------
# /outfits/{id}/reasoning
# ---------------------------------------------------------------------------


def test_reasoning_returns_full_text_and_items(authed_client, db):
    items = make_starter_wardrobe(db, authed_client.test_user, count=6)
    outfit = make_outfit(db, authed_client.test_user, items=items[:4])
    r = authed_client.get(f"/api/v1/outfits/{outfit.id}/reasoning")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["outfit_id"] == str(outfit.id)
    assert body["full_text"]
    assert len(body["items"]) == 4
    assert body["compatibility_score"] is not None
    assert body["compatibility_label"] in (
        "High compatibility", "Solid compatibility", "Could be better"
    )


def test_reasoning_cross_user_returns_404(client, make_user, auth_headers, db):
    alice = make_user(email="alice@example.com")
    bob = make_user(email="bob@example.com")
    items = make_starter_wardrobe(db, alice, count=4)
    outfit = make_outfit(db, alice, items=items)
    r = client.get(
        f"/api/v1/outfits/{outfit.id}/reasoning", headers=auth_headers(bob)
    )
    assert r.status_code == 404


# ---------------------------------------------------------------------------
# /outfits/{id}/regenerate
# ---------------------------------------------------------------------------


def test_regenerate_returns_new_outfit_with_disjoint_items(authed_client, db):
    items = make_starter_wardrobe(db, authed_client.test_user, count=9)
    prior = make_outfit(db, authed_client.test_user, items=items[:4])
    prior_ids = {it["item_id"] for it in prior.items}

    r = authed_client.post(f"/api/v1/outfits/{prior.id}/regenerate")
    assert r.status_code == 200, r.text
    fresh = r.json()
    fresh_ids = {it["item_id"] for it in fresh["items"]}
    assert fresh["id"] != str(prior.id)
    # CannedAIProvider picks the first 4 ids in the prompt; regenerate excludes
    # prior items, so the new set must be disjoint when wardrobe ≥ 8 items.
    assert fresh_ids.isdisjoint(prior_ids), \
        f"regenerate didn't exclude prior items: {fresh_ids & prior_ids}"


def test_regenerate_unknown_outfit_returns_404(authed_client):
    fake_id = "00000000-0000-0000-0000-000000000000"
    r = authed_client.post(f"/api/v1/outfits/{fake_id}/regenerate")
    assert r.status_code == 404


def test_regenerate_cross_user_returns_404(client, make_user, auth_headers, db):
    alice = make_user(email="alice@example.com")
    bob = make_user(email="bob@example.com")
    items = make_starter_wardrobe(db, alice, count=4)
    outfit = make_outfit(db, alice, items=items)
    r = client.post(
        f"/api/v1/outfits/{outfit.id}/regenerate", headers=auth_headers(bob)
    )
    assert r.status_code == 404


# ---------------------------------------------------------------------------
# /outfits/{id}/mix-and-match  (deterministic; no AI roundtrip)
# ---------------------------------------------------------------------------


def test_mix_and_match_swaps_item_and_recomputes_score(authed_client, db):
    items = make_starter_wardrobe(db, authed_client.test_user, count=6)
    outfit = make_outfit(db, authed_client.test_user, items=items[:4])
    old_id, new_id = items[0].id, items[4].id

    r = authed_client.post(
        f"/api/v1/outfits/{outfit.id}/mix-and-match",
        json={"swapped_items": [{"old_item_id": str(old_id), "new_item_id": str(new_id)}]},
    )
    assert r.status_code == 200, r.text
    body = r.json()
    new_ids = {it["item_id"] for it in body["items"]}
    assert str(old_id) not in new_ids
    assert str(new_id) in new_ids
    assert body["compatibility_score"] is not None


def test_mix_and_match_round_trip_restores_items(authed_client, db):
    """A→B then B→A should restore the original *item set* on the outfit row.

    We don't assert on the literal compatibility_score, because the score
    seeded by the factory (80) is a placeholder, while mix-and-match always
    recomputes via `_compatibility_score(items)` — a deterministic function
    of the item set. So the meaningful invariant is: items round-trip back.
    """
    items = make_starter_wardrobe(db, authed_client.test_user, count=6)
    outfit = make_outfit(db, authed_client.test_user, items=items[:4])
    original_item_ids = sorted(str(i.id) for i in items[:4])
    old_id, new_id = items[0].id, items[4].id

    authed_client.post(
        f"/api/v1/outfits/{outfit.id}/mix-and-match",
        json={"swapped_items": [{"old_item_id": str(old_id), "new_item_id": str(new_id)}]},
    )
    r_back = authed_client.post(
        f"/api/v1/outfits/{outfit.id}/mix-and-match",
        json={"swapped_items": [{"old_item_id": str(new_id), "new_item_id": str(old_id)}]},
    )
    assert r_back.status_code == 200
    final_item_ids = sorted(it["item_id"] for it in r_back.json()["items"])
    assert final_item_ids == original_item_ids


def test_mix_and_match_scorer_is_deterministic(authed_client, db):
    """Same swap, run twice → same score. Proves the scorer is pure (no
    hidden state) without coupling the test to specific score values."""
    items = make_starter_wardrobe(db, authed_client.test_user, count=6)
    outfit = make_outfit(db, authed_client.test_user, items=items[:4])
    old_id, new_id = items[0].id, items[4].id
    payload = {"swapped_items": [{"old_item_id": str(old_id), "new_item_id": str(new_id)}]}

    r1 = authed_client.post(f"/api/v1/outfits/{outfit.id}/mix-and-match", json=payload)
    # Swap back so the next A→B starts from the same item set.
    authed_client.post(
        f"/api/v1/outfits/{outfit.id}/mix-and-match",
        json={"swapped_items": [{"old_item_id": str(new_id), "new_item_id": str(old_id)}]},
    )
    r2 = authed_client.post(f"/api/v1/outfits/{outfit.id}/mix-and-match", json=payload)
    assert r1.json()["compatibility_score"] == r2.json()["compatibility_score"]


def test_mix_and_match_with_unknown_new_item_returns_400(authed_client, db):
    items = make_starter_wardrobe(db, authed_client.test_user, count=4)
    outfit = make_outfit(db, authed_client.test_user, items=items)
    fake = "00000000-0000-0000-0000-000000000000"
    r = authed_client.post(
        f"/api/v1/outfits/{outfit.id}/mix-and-match",
        json={"swapped_items": [{"old_item_id": str(items[0].id), "new_item_id": fake}]},
    )
    assert r.status_code == 400


def test_mix_and_match_with_other_users_item_returns_400(client, make_user, auth_headers, db):
    """Service must validate the new item belongs to the calling user, not
    just exist somewhere in the DB. Otherwise Bob could swap Alice's blouse in."""
    alice = make_user(email="alice@example.com")
    bob = make_user(email="bob@example.com")
    bob_items = make_starter_wardrobe(db, bob, count=4)
    bob_outfit = make_outfit(db, bob, items=bob_items)
    alice_items = make_starter_wardrobe(db, alice, count=2)

    r = client.post(
        f"/api/v1/outfits/{bob_outfit.id}/mix-and-match",
        headers=auth_headers(bob),
        json={
            "swapped_items": [
                {"old_item_id": str(bob_items[0].id), "new_item_id": str(alice_items[0].id)}
            ]
        },
    )
    assert r.status_code == 400


# ---------------------------------------------------------------------------
# /outfits/{id}/log + streak + toast variants
# ---------------------------------------------------------------------------


def test_log_first_outfit_returns_default_toast_and_streak_1(authed_client, db):
    items = make_starter_wardrobe(db, authed_client.test_user, count=4)
    outfit = make_outfit(db, authed_client.test_user, items=items)

    r = authed_client.post(f"/api/v1/outfits/{outfit.id}/log")
    assert r.status_code == 200, r.text
    body = r.json()
    assert body["toast"]["type"] == "default"
    assert body["current_streak"] == 1
    assert body["total_outfits_logged"] == 1


def test_log_advances_streak_to_streak_toast(authed_client, db):
    """Streak toast fires when current_streak ≥ 3 AND total isn't a milestone.
    We rewrite last_logged_date to yesterday so the next log produces streak=3."""
    items = make_starter_wardrobe(db, authed_client.test_user, count=4)
    o1 = make_outfit(db, authed_client.test_user, items=items, occasion="work")
    o2 = make_outfit(db, authed_client.test_user, items=items, occasion="casual")

    # First log → streak=1, total=1.
    authed_client.post(f"/api/v1/outfits/{o1.id}/log")

    # Walk the streak: pretend yesterday's already counted.
    streak = db.scalar(
        select(StreakTracking).where(
            StreakTracking.user_id == authed_client.test_user.id
        )
    )
    streak.last_logged_date = date.today() - timedelta(days=1)
    streak.current_streak = 2
    db.commit()

    r = authed_client.post(f"/api/v1/outfits/{o2.id}/log")
    assert r.status_code == 200
    body = r.json()
    assert body["toast"]["type"] == "streak"
    assert body["current_streak"] == 3


def test_log_advances_to_milestone_toast(authed_client, db):
    """5 is a milestone (CTO doc). Pre-set total=4, then logging the 5th outfit
    fires milestone (which wins over streak by priority)."""
    items = make_starter_wardrobe(db, authed_client.test_user, count=4)
    outfit = make_outfit(db, authed_client.test_user, items=items)

    # Seed a streak row at total=4. Set last_logged_date so the next log is
    # *not* a same-day no-op.
    streak = StreakTracking(
        user_id=authed_client.test_user.id,
        current_streak=0,
        longest_streak=0,
        total_outfits_logged=4,
        last_logged_date=date.today() - timedelta(days=2),
    )
    db.add(streak)
    db.commit()

    r = authed_client.post(f"/api/v1/outfits/{outfit.id}/log")
    assert r.status_code == 200
    body = r.json()
    assert body["toast"]["type"] == "milestone"
    assert body["total_outfits_logged"] == 5


def test_log_idempotent_same_day(authed_client, db):
    """Logging the same outfit twice on the same day shouldn't double-count
    streak or total."""
    items = make_starter_wardrobe(db, authed_client.test_user, count=4)
    outfit = make_outfit(db, authed_client.test_user, items=items)

    r1 = authed_client.post(f"/api/v1/outfits/{outfit.id}/log").json()
    r2 = authed_client.post(f"/api/v1/outfits/{outfit.id}/log").json()
    assert r1["current_streak"] == r2["current_streak"]
    assert r1["total_outfits_logged"] == r2["total_outfits_logged"]


def test_log_unknown_outfit_returns_404(authed_client):
    fake_id = "00000000-0000-0000-0000-000000000000"
    r = authed_client.post(f"/api/v1/outfits/{fake_id}/log")
    assert r.status_code == 404


# ---------------------------------------------------------------------------
# /outfits/history
# ---------------------------------------------------------------------------


def test_history_empty_returns_zero(authed_client):
    r = authed_client.get("/api/v1/outfits/history?filter=all")
    assert r.status_code == 200
    body = r.json()
    assert body["total_count"] == 0
    assert body["filter"] == "all"


def test_history_after_log_includes_outfit(authed_client, db):
    items = make_starter_wardrobe(db, authed_client.test_user, count=4)
    outfit = make_outfit(db, authed_client.test_user, items=items)
    authed_client.post(f"/api/v1/outfits/{outfit.id}/log")

    r = authed_client.get("/api/v1/outfits/history?filter=all")
    assert r.status_code == 200
    body = r.json()
    assert body["total_count"] == 1
    assert body["outfits"][0]["outfit_id"] == str(outfit.id)


def test_history_this_week_filter(authed_client, db):
    items = make_starter_wardrobe(db, authed_client.test_user, count=4)
    outfit = make_outfit(db, authed_client.test_user, items=items)
    authed_client.post(f"/api/v1/outfits/{outfit.id}/log")

    r_all = authed_client.get("/api/v1/outfits/history?filter=all")
    r_week = authed_client.get("/api/v1/outfits/history?filter=this_week")
    # Today's log falls inside this_week → both counts equal.
    assert r_all.json()["total_count"] == r_week.json()["total_count"] == 1
    assert r_week.json()["filter"] == "this_week"


def test_history_bad_filter_returns_422(authed_client):
    r = authed_client.get("/api/v1/outfits/history?filter=last_year")
    assert r.status_code == 422
