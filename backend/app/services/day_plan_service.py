"""Day plans — what the user has on each day (Plan your week / Plan a day).

Two tables:

* `day_plans` — one row per (user, date): a one-off plan, or an override of
  the weekday's repeat for that one date (`skipped` = nothing planned).
* `weekly_plan_rules` — "Repeat every <weekday>", effective-dated
  (`starts_on` … `ends_on`) so changing a repeat never rewrites past days.

A day resolves to: its own row (skipped → no plan), else the rule covering
that date, else no plan.

Writes:

* scope="day" — "Just this <weekday>": a row for that date (and, with
  `until`, each same-weekday date up to it — a temporary change). The repeat
  is untouched and resumes after.
* scope="from_now" — "Every <weekday> from now on": ends the current repeat
  the day before and (on save) starts the new one. Skips made for the old
  repeat on/after that date go with it (they only existed to hide it);
  one-off plans the user set for specific dates stay.

Dates are the user's local app days (`core.localtime.user_today`). Past days
are read-only, so history stays what the user actually planned.
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, timedelta
from typing import Optional

import structlog
from sqlalchemy import delete, func, or_, select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.core.localtime import user_today
from app.db.models import DayPlan, User, WeeklyPlanRule

_log = structlog.get_logger("day_plans")

# How far ahead a plan (or an `until`) may go.
MAX_AHEAD_DAYS = 365
# Longest range one read may ask for.
MAX_RANGE_DAYS = 62
# Default read: today + the next six days ("Your next 7 days").
DEFAULT_RANGE_DAYS = 7

# Day occasion → the outfit occasion the stylist styles for it
# (`app/data/occasion_rules.yaml`). The dress level carries the finer
# formality (e.g. a school meeting is `casual` at smart-casual).
OUTFIT_OCCASION: dict[str, str] = {
    "work_day": "work",
    "remote_day": "casual",
    "day_off": "casual",
    "official_meeting": "work",
    "school": "casual",
    "interview": "interview",
    "date_dinner": "date_night",
    "formal_event": "wedding_guest",
    "travel": "travel",
    "workout": "gym",
    "friends": "brunch",
    "other": "other",
}


class DayPlanError(Exception):
    """Typed domain error; routes map every code to 422."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class ResolvedDay:
    date: date
    occasion: Optional[str]
    dress_level: Optional[str]
    note: Optional[str]
    # "day" (its own row) | "weekly" (from the repeat) | None (no plan).
    source: Optional[str]
    # A repeat covers this weekday on this date, overridden or not.
    repeats_weekly: bool

    @property
    def has_plan(self) -> bool:
        return self.occasion is not None


# ---------------------------------------------------------------------------
# Reads
# ---------------------------------------------------------------------------


def resolve_range(
    db: Session, *, user: User, start: date | None = None, end: date | None = None
) -> list[ResolvedDay]:
    """Each day from `start` to `end` inclusive (default: the next 7 days)."""
    if start is None:
        start = user_today(user)
    if end is None:
        end = start + timedelta(days=DEFAULT_RANGE_DAYS - 1)
    if end < start:
        raise DayPlanError("bad_range", "'to' must be on or after 'from'.")
    if (end - start).days + 1 > MAX_RANGE_DAYS:
        raise DayPlanError(
            "bad_range", f"Ask for at most {MAX_RANGE_DAYS} days at a time."
        )

    overrides = {
        row.plan_date: row
        for row in db.scalars(
            select(DayPlan).where(
                DayPlan.user_id == user.id,
                DayPlan.plan_date >= start,
                DayPlan.plan_date <= end,
            )
        )
    }
    rules = list(
        db.scalars(
            select(WeeklyPlanRule).where(
                WeeklyPlanRule.user_id == user.id,
                WeeklyPlanRule.starts_on <= end,
                or_(WeeklyPlanRule.ends_on.is_(None), WeeklyPlanRule.ends_on >= start),
            )
        )
    )

    days: list[ResolvedDay] = []
    day = start
    while day <= end:
        rule = _covering(rules, day)
        row = overrides.get(day)
        if row is not None:
            if row.skipped:
                days.append(ResolvedDay(day, None, None, None, None, rule is not None))
            else:
                days.append(
                    ResolvedDay(
                        day, row.occasion, row.dress_level, row.note, "day", rule is not None
                    )
                )
        elif rule is not None:
            days.append(
                ResolvedDay(day, rule.occasion, rule.dress_level, rule.note, "weekly", True)
            )
        else:
            days.append(ResolvedDay(day, None, None, None, None, False))
        day += timedelta(days=1)
    return days


def resolve_day(db: Session, *, user: User, day: date) -> ResolvedDay:
    return resolve_range(db, user=user, start=day, end=day)[0]


# ---------------------------------------------------------------------------
# Writes
# ---------------------------------------------------------------------------


def save(
    db: Session,
    *,
    user: User,
    day: date,
    occasion: str,
    dress_level: str,
    note: Optional[str],
    scope: str = "day",
    until: Optional[date] = None,
) -> ResolvedDay:
    """Plan a day's Save. Returns how `day` resolves afterwards."""
    _check_day(user, day)
    _check_until(user, day, until)
    _lock_user(db, user)

    if scope == "day":
        for d in _same_weekday_dates(day, until):
            _upsert_override(
                db, user=user, day=d, occasion=occasion, dress_level=dress_level, note=note
            )
    else:
        _end_repeat_from(db, user=user, day=day)
        db.add(
            WeeklyPlanRule(
                user_id=user.id,
                weekday=day.weekday(),
                occasion=occasion,
                dress_level=dress_level,
                note=note,
                starts_on=day,
                ends_on=until,
            )
        )
        # The day itself now shows the new repeat.
        db.execute(
            delete(DayPlan).where(DayPlan.user_id == user.id, DayPlan.plan_date == day)
        )
    db.commit()
    _log.info(
        "day_plan.saved",
        user_id=str(user.id),
        scope=scope,
        weekday=day.weekday(),
        has_until=until is not None,
    )
    return resolve_day(db, user=user, day=day)


def clear(
    db: Session,
    *,
    user: User,
    day: date,
    scope: str = "day",
    until: Optional[date] = None,
) -> ResolvedDay:
    """Plan a day's "Clear plan". scope="day" clears just that date (and,
    with `until`, each same-weekday date up to it); scope="from_now" stops
    the repeat from that date on."""
    _check_day(user, day)
    if scope == "from_now" and until is not None:
        raise DayPlanError("bad_until", "'until' only applies to clearing single days.")
    _check_until(user, day, until)
    _lock_user(db, user)

    if scope == "day":
        dates = _same_weekday_dates(day, until)
        rules = _rules_for_weekday(db, user=user, weekday=day.weekday())
        for d in dates:
            if _covering(rules, d) is not None:
                # Hide the repeat for this one date.
                _upsert_override(db, user=user, day=d, skipped=True)
            else:
                db.execute(
                    delete(DayPlan).where(DayPlan.user_id == user.id, DayPlan.plan_date == d)
                )
    else:
        _end_repeat_from(db, user=user, day=day)
        db.execute(
            delete(DayPlan).where(DayPlan.user_id == user.id, DayPlan.plan_date == day)
        )
    db.commit()
    _log.info("day_plan.cleared", user_id=str(user.id), scope=scope, has_until=until is not None)
    return resolve_day(db, user=user, day=day)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _check_day(user: User, day: date) -> None:
    today = user_today(user)
    if day < today:
        raise DayPlanError("past_date", "Past days can't be changed.")
    if day > today + timedelta(days=MAX_AHEAD_DAYS):
        raise DayPlanError(
            "too_far", f"Plans can go up to {MAX_AHEAD_DAYS} days ahead."
        )


def _check_until(user: User, day: date, until: Optional[date]) -> None:
    if until is None:
        return
    if until < day:
        raise DayPlanError("bad_until", "'until' must be on or after the day.")
    if until > user_today(user) + timedelta(days=MAX_AHEAD_DAYS):
        raise DayPlanError(
            "bad_until", f"'until' can be at most {MAX_AHEAD_DAYS} days ahead."
        )


def _lock_user(db: Session, user: User) -> None:
    """Serialize one user's plan writes, so the one-rule-per-date invariant
    holds under concurrent saves (two devices, a double tap)."""
    db.execute(select(User.id).where(User.id == user.id).with_for_update())


def _same_weekday_dates(day: date, until: Optional[date]) -> list[date]:
    dates = [day]
    if until is not None:
        d = day + timedelta(days=7)
        while d <= until:
            dates.append(d)
            d += timedelta(days=7)
    return dates


def _covering(rules: list[WeeklyPlanRule], day: date) -> Optional[WeeklyPlanRule]:
    for rule in rules:
        if (
            rule.weekday == day.weekday()
            and rule.starts_on <= day
            and (rule.ends_on is None or rule.ends_on >= day)
        ):
            return rule
    return None


def _rules_for_weekday(db: Session, *, user: User, weekday: int) -> list[WeeklyPlanRule]:
    return list(
        db.scalars(
            select(WeeklyPlanRule).where(
                WeeklyPlanRule.user_id == user.id, WeeklyPlanRule.weekday == weekday
            )
        )
    )


def _end_repeat_from(db: Session, *, user: User, day: date) -> None:
    """Stops `day`'s weekday repeating from `day` on: later-starting rules are
    removed, a rule running through `day` ends the day before, and skips that
    only hid the old repeat on/after `day` are dropped."""
    weekday = day.weekday()
    for rule in _rules_for_weekday(db, user=user, weekday=weekday):
        if rule.starts_on >= day:
            db.delete(rule)
        elif rule.ends_on is None or rule.ends_on >= day:
            rule.ends_on = day - timedelta(days=1)
    db.flush()

    skipped = db.scalars(
        select(DayPlan).where(
            DayPlan.user_id == user.id,
            DayPlan.skipped.is_(True),
            DayPlan.plan_date >= day,
        )
    )
    for row in skipped:
        if row.plan_date.weekday() == weekday:
            db.delete(row)
    db.flush()


def _upsert_override(
    db: Session,
    *,
    user: User,
    day: date,
    occasion: Optional[str] = None,
    dress_level: Optional[str] = None,
    note: Optional[str] = None,
    skipped: bool = False,
) -> None:
    values = {
        "occasion": None if skipped else occasion,
        "dress_level": None if skipped else dress_level,
        "note": None if skipped else note,
        "skipped": skipped,
    }
    stmt = insert(DayPlan).values(user_id=user.id, plan_date=day, **values)
    db.execute(
        stmt.on_conflict_do_update(
            index_elements=[DayPlan.user_id, DayPlan.plan_date],
            set_={**values, "updated_at": func.now()},
        )
    )
