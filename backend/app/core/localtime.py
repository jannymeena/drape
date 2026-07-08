"""User-local time helpers (Tier 1.2).

The Today handoff defines the app's clock in the *user's* timezone: weekly
usage resets Monday 05:00 local, and the day cycle runs 5am-to-5am (the
greeting switches at 5am, not midnight). These helpers give every service the
same notion of "the user's current day" — a log at 1 AM local counts toward
the evening before, and a user in Toronto isn't flipped to tomorrow at 8 PM
because UTC rolled over.

Falls back to UTC when `users.timezone` is null or unparseable (same policy
as the weekly usage window).
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from typing import TYPE_CHECKING
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

import structlog

if TYPE_CHECKING:
    from app.db.models import User

_log = structlog.get_logger("localtime")

# The app day rolls over at 05:00 local (Today handoff — mirrors the
# Monday-05:00 weekly usage reset).
DAY_ROLLOVER_HOUR = 5


def user_tz(user: "User") -> ZoneInfo:
    if user.timezone:
        try:
            return ZoneInfo(user.timezone)
        except ZoneInfoNotFoundError:
            _log.warning("localtime.bad_tz", user_id=str(user.id), tz=user.timezone)
    return ZoneInfo("UTC")


def as_user_day(user: "User", at_utc: datetime) -> date:
    """Map a UTC instant onto the user's app day (5am-to-5am local)."""
    if at_utc.tzinfo is None:  # defensive: columns are timezone=True
        at_utc = at_utc.replace(tzinfo=timezone.utc)
    local = at_utc.astimezone(user_tz(user))
    return (local - timedelta(hours=DAY_ROLLOVER_HOUR)).date()


def user_today(user: "User", *, now_utc: datetime | None = None) -> date:
    """The user's current app day."""
    return as_user_day(user, now_utc or datetime.now(timezone.utc))


def user_day_start_utc(user: "User", *, now_utc: datetime | None = None) -> datetime:
    """UTC instant when the user's current app day began (05:00 local)."""
    start_local = datetime.combine(
        user_today(user, now_utc=now_utc),
        time(DAY_ROLLOVER_HOUR, 0),
        tzinfo=user_tz(user),
    )
    return start_local.astimezone(timezone.utc)


def next_day_rollover_utc(user: "User", *, now_utc: datetime | None = None) -> datetime:
    """UTC instant when the user's next app day begins (tomorrow 05:00 local).
    Drives the dashboard's daily-reset countdown."""
    next_local = datetime.combine(
        user_today(user, now_utc=now_utc) + timedelta(days=1),
        time(DAY_ROLLOVER_HOUR, 0),
        tzinfo=user_tz(user),
    )
    return next_local.astimezone(timezone.utc)
