"""Tier 1.2 — user-local app-day math (05:00-local rollover).

The app day runs 5am-to-5am in the user's timezone (Today handoff — the same
clock as the Monday-05:00 weekly usage reset). These tests pin the boundary
behaviour: late-evening logs stay on the local day even after UTC rolls over,
1-4am logs count toward the evening before, and DST transitions don't shift
the rollover instant.
"""
from __future__ import annotations

import uuid
from datetime import date, datetime, timezone
from types import SimpleNamespace

from app.core import localtime


def _user(tz: str | None):
    return SimpleNamespace(id=uuid.uuid4(), timezone=tz)


def _utc(y, m, d, hh, mm=0):
    return datetime(y, m, d, hh, mm, tzinfo=timezone.utc)


# ---------------------------------------------------------------------------
# as_user_day / user_today
# ---------------------------------------------------------------------------


def test_evening_log_stays_on_the_local_day_after_utc_midnight():
    # 23:30 in Toronto on July 7 = 03:30 UTC July 8. The user's day is still
    # July 7 — this is exactly the case UTC-pinned streaks got wrong.
    user = _user("America/Toronto")  # UTC-4 in July
    assert localtime.as_user_day(user, _utc(2026, 7, 8, 3, 30)) == date(2026, 7, 7)


def test_small_hours_count_toward_the_evening_before():
    # 01:30 local is before the 05:00 rollover — still the previous app day.
    user = _user("America/Toronto")
    local_0130 = _utc(2026, 7, 8, 5, 30)  # 01:30 Toronto
    assert localtime.as_user_day(user, local_0130) == date(2026, 7, 7)


def test_rollover_boundary_is_5am_local():
    user = _user("America/Toronto")
    before = _utc(2026, 7, 8, 8, 59)  # 04:59 Toronto
    after = _utc(2026, 7, 8, 9, 1)  # 05:01 Toronto
    assert localtime.as_user_day(user, before) == date(2026, 7, 7)
    assert localtime.as_user_day(user, after) == date(2026, 7, 8)


def test_ahead_of_utc_timezone():
    # Tokyo (UTC+9): 13:00 UTC July 7 = 22:00 local July 7 → app day July 7;
    # 19:30 UTC July 7 = 04:30 local July 8 → still app day July 7.
    user = _user("Asia/Tokyo")
    assert localtime.as_user_day(user, _utc(2026, 7, 7, 13, 0)) == date(2026, 7, 7)
    assert localtime.as_user_day(user, _utc(2026, 7, 7, 19, 30)) == date(2026, 7, 7)
    assert localtime.as_user_day(user, _utc(2026, 7, 7, 20, 30)) == date(2026, 7, 8)


def test_null_or_bad_timezone_falls_back_to_utc():
    for tz in (None, "Not/AZone"):
        user = _user(tz)
        assert localtime.as_user_day(user, _utc(2026, 7, 8, 4, 59)) == date(2026, 7, 7)
        assert localtime.as_user_day(user, _utc(2026, 7, 8, 5, 1)) == date(2026, 7, 8)


def test_naive_datetime_treated_as_utc():
    user = _user("America/Toronto")
    naive = datetime(2026, 7, 8, 3, 30)  # defensive path; columns are tz-aware
    assert localtime.as_user_day(user, naive) == date(2026, 7, 7)


# ---------------------------------------------------------------------------
# Day-start / next-rollover instants
# ---------------------------------------------------------------------------


def test_day_start_is_5am_local_in_utc():
    user = _user("America/Toronto")
    now = _utc(2026, 7, 7, 18, 0)  # 14:00 Toronto, app day July 7
    start = localtime.user_day_start_utc(user, now_utc=now)
    assert start == _utc(2026, 7, 7, 9, 0)  # 05:00 Toronto


def test_next_rollover_is_tomorrow_5am_local():
    user = _user("America/Toronto")
    now = _utc(2026, 7, 7, 18, 0)
    nxt = localtime.next_day_rollover_utc(user, now_utc=now)
    assert nxt == _utc(2026, 7, 8, 9, 0)
    assert nxt > now


def test_dst_transition_keeps_5am_wall_clock():
    # North American DST starts 2026-03-08 (clocks jump 02:00→03:00). The day
    # start stays 05:00 *wall clock*: EST day starts at 10:00 UTC, EDT at 09:00.
    user = _user("America/Toronto")
    before_dst = _utc(2026, 3, 7, 15, 0)  # Mar 7, EST (UTC-5)
    after_dst = _utc(2026, 3, 9, 15, 0)  # Mar 9, EDT (UTC-4)
    assert localtime.user_day_start_utc(user, now_utc=before_dst) == _utc(2026, 3, 7, 10, 0)
    assert localtime.user_day_start_utc(user, now_utc=after_dst) == _utc(2026, 3, 9, 9, 0)


def test_streak_consecutive_local_evenings_are_consecutive_app_days():
    # Mon 22:00 and Tue 21:30 Toronto both land after UTC midnight (02:00 /
    # 01:30 UTC next day) — under UTC dates they'd be Tue+Wed with a possible
    # same-day collision or gap; under app days they're cleanly Mon then Tue.
    user = _user("America/Toronto")
    monday_evening = _utc(2026, 7, 7, 2, 0)  # Mon Jul 6, 22:00 Toronto
    tuesday_evening = _utc(2026, 7, 8, 1, 30)  # Tue Jul 7, 21:30 Toronto
    d1 = localtime.as_user_day(user, monday_evening)
    d2 = localtime.as_user_day(user, tuesday_evening)
    assert (d1, d2) == (date(2026, 7, 6), date(2026, 7, 7))
    assert (d2 - d1).days == 1  # exactly what _advance_streak needs to see
