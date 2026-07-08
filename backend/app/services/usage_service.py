"""Phase 6d — weekly usage tracking + free-tier limits.

Exposes:
  * `get_or_create_current_week(user)` — returns the user's row for this week,
    creating it on demand. Idempotent.
  * `check_and_increment(user, resource)` — atomic check-and-bump. Raises
    `UsageError("limit_reached", ...)` for free users who've hit the cap;
    Pro users bypass the bump entirely (no row needed).
  * `get_summary(user)` — assembled `CurrentWeekUsage` for the dashboard /
    `/usage/current-week` endpoint.

Week window: Monday 05:00 in the user's timezone (CTO doc 2). Falls back to
UTC when `users.timezone` is null. The reset timestamp is exposed verbatim to
the client so it can render the countdown.

Why the limits live as columns on usage_tracking (not constants): a per-user
override (e.g. comp'd reviewer accounts) becomes a single UPDATE rather than a
service rewrite. The subscription_tier check happens *outside* this row — Pro
users skip the row entirely.
"""
from __future__ import annotations

from datetime import date, datetime, time, timedelta, timezone
from typing import Optional
from zoneinfo import ZoneInfo

import structlog
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.localtime import user_tz as _user_tz
from app.db.models import UsageTracking, User
from app.schemas.usage import (
    CurrentWeekUsage,
    SubscriptionTier,
    UsageCounters,
    UsageResource,
)

_log = structlog.get_logger("usage")


# CTO doc 2 §"Free tier limits".
DEFAULT_OUTFIT_LIMIT = 21
DEFAULT_MIX_LIMIT = 3
# CTO doc 4 §Shop free limits.
DEFAULT_BDB_LIMIT = 5
DEFAULT_ADVISOR_LIMIT = 10

# Reset clock: Monday 05:00 in the user's timezone.
_RESET_HOUR_LOCAL = 5


class UsageError(Exception):
    """Domain-level usage failure. Routes translate `limit_reached` to 429."""

    def __init__(
        self,
        code: str,
        message: str,
        *,
        resource: Optional[UsageResource] = None,
        used: int = 0,
        limit: int = 0,
        resets_at: Optional[datetime] = None,
    ) -> None:
        super().__init__(message)
        self.code = code
        self.resource = resource
        self.used = used
        self.limit = limit
        self.resets_at = resets_at


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _week_window_local(now_utc: datetime, tz: ZoneInfo) -> tuple[date, datetime, datetime]:
    """Return (week_start_date, last_reset_utc, next_reset_utc).

    The week starts on Monday at _RESET_HOUR_LOCAL local time. If `now_utc`
    is between Mon 00:00 and Mon 05:00 local time, the *current* week's reset
    timestamp is in the future — i.e. we still belong to the prior week. The
    column `last_reset` always points at the boundary that's already past.
    """
    now_local = now_utc.astimezone(tz)
    # Monday-of-this-week in local time.
    monday_this_local = (now_local - timedelta(days=now_local.weekday())).date()
    reset_this_local = datetime.combine(
        monday_this_local, time(_RESET_HOUR_LOCAL, 0), tzinfo=tz
    )
    if now_local < reset_this_local:
        # Before this week's Monday-5am — we're in the previous week's window.
        last_reset_local = reset_this_local - timedelta(days=7)
        next_reset_local = reset_this_local
        week_start = (monday_this_local - timedelta(days=7))
    else:
        last_reset_local = reset_this_local
        next_reset_local = reset_this_local + timedelta(days=7)
        week_start = monday_this_local
    return (
        week_start,
        last_reset_local.astimezone(timezone.utc),
        next_reset_local.astimezone(timezone.utc),
    )


def _is_pro(user: User) -> bool:
    return (user.subscription_tier or "free") == "pro"


def _tier(user: User) -> SubscriptionTier:
    return "pro" if _is_pro(user) else "free"


def get_or_create_current_week(db: Session, *, user: User) -> UsageTracking:
    """Atomically returns the row for (user, current_week). Uses a tight
    insert-then-fetch pattern so two concurrent requests can't double-create
    on the (user_id, week_start_date) UNIQUE constraint."""
    tz = _user_tz(user)
    week_start, last_reset, next_reset = _week_window_local(_now(), tz)

    row = db.scalar(
        select(UsageTracking).where(
            UsageTracking.user_id == user.id,
            UsageTracking.week_start_date == week_start,
        )
    )
    if row is not None:
        # Refresh reset timestamps in case timezone changed.
        if row.next_reset != next_reset:
            row.last_reset = last_reset
            row.next_reset = next_reset
            db.commit()
            db.refresh(row)
        return row

    row = UsageTracking(
        user_id=user.id,
        week_start_date=week_start,
        outfits_generated=0,
        mix_and_match_sessions=0,
        outfit_limit=DEFAULT_OUTFIT_LIMIT,
        mix_limit=DEFAULT_MIX_LIMIT,
        buy_dont_buy_checks=0,
        buy_dont_buy_limit=DEFAULT_BDB_LIMIT,
        advisor_questions=0,
        advisor_limit=DEFAULT_ADVISOR_LIMIT,
        last_reset=last_reset,
        next_reset=next_reset,
    )
    db.add(row)
    try:
        db.commit()
    except IntegrityError:
        # Another request beat us to it.
        db.rollback()
        row = db.scalar(
            select(UsageTracking).where(
                UsageTracking.user_id == user.id,
                UsageTracking.week_start_date == week_start,
            )
        )
        if row is None:
            raise
    db.refresh(row)
    return row


def _resource_used_limit(row: UsageTracking, resource: UsageResource) -> tuple[int, int]:
    if resource == "outfits":
        return row.outfits_generated, row.outfit_limit
    if resource == "mix_and_match":
        return row.mix_and_match_sessions, row.mix_limit
    if resource == "buy_dont_buy":
        return row.buy_dont_buy_checks, row.buy_dont_buy_limit
    return row.advisor_questions, row.advisor_limit


def _bump(row: UsageTracking, resource: UsageResource, count: int) -> None:
    if resource == "outfits":
        row.outfits_generated += count
    elif resource == "mix_and_match":
        row.mix_and_match_sessions += count
    elif resource == "buy_dont_buy":
        row.buy_dont_buy_checks += count
    else:
        row.advisor_questions += count


def check_and_increment(
    db: Session, *, user: User, resource: UsageResource, count: int = 1
) -> UsageTracking:
    """Atomic check-and-increment. No-op for Pro users.

    Raises UsageError('limit_reached') when the requested `count` would push
    the user past the weekly limit. The error carries `resets_at` so the route
    can render the countdown without a follow-up read.
    """
    if _is_pro(user):
        # Pro: unbounded. Skip the row entirely — keeps usage_tracking focused
        # on the free population that's actually rate-limited. The detached
        # row is never persisted; the service just returns it so callers have
        # a uniform shape.
        _, _, next_reset = _week_window_local(_now(), _user_tz(user))
        return UsageTracking(
            user_id=user.id,
            week_start_date=date.today(),
            outfits_generated=0,
            mix_and_match_sessions=0,
            outfit_limit=10**9,
            mix_limit=10**9,
            buy_dont_buy_checks=0,
            buy_dont_buy_limit=10**9,
            advisor_questions=0,
            advisor_limit=10**9,
            last_reset=None,
            next_reset=next_reset,
        )

    row = get_or_create_current_week(db, user=user)
    used, limit = _resource_used_limit(row, resource)
    if used + count > limit:
        _log.info(
            "usage.limit_reached",
            user_id=str(user.id),
            resource=resource,
            used=used,
            limit=limit,
            requested=count,
        )
        raise UsageError(
            "limit_reached",
            f"Weekly {resource} limit reached ({used}/{limit}). "
            f"Resets at {row.next_reset.isoformat() if row.next_reset else 'next Monday 05:00'}.",
            resource=resource,
            used=used,
            limit=limit,
            resets_at=row.next_reset,  # type: ignore[arg-type]
        )

    _bump(row, resource, count)
    db.commit()
    db.refresh(row)
    _log.info(
        "usage.incremented",
        user_id=str(user.id),
        resource=resource,
        new_used=used + count,
        limit=limit,
    )
    return row


def get_summary(db: Session, *, user: User) -> CurrentWeekUsage:
    row = get_or_create_current_week(db, user=user)
    pro = _is_pro(user)

    def counters(used: int, limit: int) -> UsageCounters:
        effective_limit = limit if not pro else 10**9
        remaining = max(effective_limit - used, 0)
        pct = (used / effective_limit * 100.0) if effective_limit > 0 else 0.0
        return UsageCounters(
            used=used,
            limit=effective_limit,
            remaining=remaining,
            percentage=round(pct, 2),
        )

    return CurrentWeekUsage(
        week_start_date=row.week_start_date,  # type: ignore[arg-type]
        outfits=counters(row.outfits_generated, row.outfit_limit),
        mix_and_match=counters(row.mix_and_match_sessions, row.mix_limit),
        buy_dont_buy=counters(row.buy_dont_buy_checks, row.buy_dont_buy_limit),
        advisor=counters(row.advisor_questions, row.advisor_limit),
        last_reset=row.last_reset,
        next_reset=row.next_reset,  # type: ignore[arg-type]
        subscription_tier=_tier(user),
    )
