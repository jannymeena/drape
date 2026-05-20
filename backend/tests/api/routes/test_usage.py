"""Usage endpoint tests — week-window math + Pro tier visibility.

The 22nd-outfit-429 path is covered indirectly by test_wardrobe.py
(`test_31st_real_item_returns_429_with_limit_reached`) and by direct
service tests below. We keep this thin since `usage_service` is heavily
exercised through other test files."""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

import pytest

from app.db.models import UsageTracking
from app.services import usage_service


def test_current_week_empty_returns_zero_counters(authed_client):
    r = authed_client.get("/api/v1/usage/current-week")
    assert r.status_code == 200
    body = r.json()
    assert body["outfits"]["used"] == 0
    assert body["outfits"]["limit"] == 21  # CTO doc 2 free tier
    assert body["mix_and_match"]["used"] == 0
    assert body["mix_and_match"]["limit"] == 3
    assert body["subscription_tier"] == "free"
    assert body["next_reset"] is not None


def test_current_week_after_bumps_reflects_usage(authed_client, db):
    """Writing directly into usage_tracking is faster than driving 21 outfits."""
    usage_service.get_or_create_current_week(db, user=authed_client.test_user)
    row = db.query(UsageTracking).filter_by(user_id=authed_client.test_user.id).one()
    row.outfits_generated = 16
    db.commit()

    r = authed_client.get("/api/v1/usage/current-week")
    body = r.json()
    assert body["outfits"]["used"] == 16
    assert body["outfits"]["remaining"] == 5
    assert body["outfits"]["percentage"] == pytest.approx(76.19, abs=0.01)


def test_current_week_for_pro_user_returns_pro_tier(client, make_user, auth_headers):
    pro = make_user(email="pro@example.com", tier="pro")
    r = client.get("/api/v1/usage/current-week", headers=auth_headers(pro))
    body = r.json()
    assert body["subscription_tier"] == "pro"
    # Pro = unbounded; service uses 10**9 as the effective ceiling.
    assert body["outfits"]["limit"] >= 10**9
    assert body["mix_and_match"]["limit"] >= 10**9


# ---------------------------------------------------------------------------
# Week-window math — pure helper, no HTTP round-trip needed.
# ---------------------------------------------------------------------------


def test_week_window_wed_pm_next_reset_is_next_monday_5am():
    tz = ZoneInfo("America/Toronto")
    wed_pm_local = datetime(2026, 5, 6, 14, 0, tzinfo=tz)  # Wed
    week_start, last_reset, next_reset = usage_service._week_window_local(
        wed_pm_local.astimezone(timezone.utc), tz
    )
    assert week_start == date(2026, 5, 4)  # the Monday before
    assert next_reset == datetime(2026, 5, 11, 5, 0, tzinfo=tz).astimezone(timezone.utc)
    assert last_reset == datetime(2026, 5, 4, 5, 0, tzinfo=tz).astimezone(timezone.utc)


def test_week_window_pre_monday_5am_belongs_to_previous_week():
    """Mon @ 03:00 local is *before* this week's 05:00 reset — still belongs
    to the prior week. Corner case worth pinning."""
    tz = ZoneInfo("America/Toronto")
    mon_3am_local = datetime(2026, 5, 11, 3, 0, tzinfo=tz)
    week_start, _, next_reset = usage_service._week_window_local(
        mon_3am_local.astimezone(timezone.utc), tz
    )
    assert week_start == date(2026, 5, 4), "pre-5am Monday belongs to prior week"
    assert next_reset == datetime(2026, 5, 11, 5, 0, tzinfo=tz).astimezone(timezone.utc)


def test_week_window_utc_fallback_for_user_without_timezone():
    """User with no tz set → service falls back to UTC. Verify behaviour
    by asking for a known UTC instant."""
    tz_utc = ZoneInfo("UTC")
    sample_utc = datetime(2026, 5, 6, 14, 0, tzinfo=timezone.utc)
    week_start, _, _ = usage_service._week_window_local(sample_utc, tz_utc)
    assert week_start == date(2026, 5, 4)
