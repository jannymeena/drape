"""Day plans — Plan your week / Plan a day (Today tab).

A day's plan comes from, in order: its own `day_plans` row (a one-off plan,
or `skipped` = nothing planned), else the weekday's repeat rule, else none.
"""
from __future__ import annotations

import datetime as dt
from typing import Literal

from pydantic import BaseModel, Field, field_validator

from app.schemas.profile import DayFormality

# The 12 "What's on" tiles on Plan a day, in display order.
DayOccasion = Literal[
    "work_day",
    "remote_day",
    "day_off",
    "official_meeting",
    "school",
    "interview",
    "date_dinner",
    "formal_event",
    "travel",
    "workout",
    "friends",
    "other",
]

# "Just this <weekday>" (an override for one date — or, with `until`, for
# each same-weekday date up to it) vs "Every <weekday> from now on" (ends
# the current repeat and starts a new one).
DayPlanScope = Literal["day", "from_now"]

# Where a resolved day's plan came from.
DayPlanSource = Literal["day", "weekly"]

NOTE_MAX = 100


class DayPlanUpsertRequest(BaseModel):
    occasion: DayOccasion
    dress_level: DayFormality
    # "Anything else?" — trimmed; blank means no note.
    note: str | None = Field(default=None, max_length=NOTE_MAX * 2)
    scope: DayPlanScope = "day"
    # scope=day: also apply to every same-weekday date up to and including
    # this one (a temporary change). scope=from_now: the new repeat's last
    # day (null = no end).
    until: dt.date | None = None

    @field_validator("note")
    @classmethod
    def _trim_note(cls, v: str | None) -> str | None:
        if v is None:
            return None
        v = v.strip()
        if len(v) > NOTE_MAX:
            raise ValueError(f"note must be at most {NOTE_MAX} characters")
        return v or None


class DayPlanBody(BaseModel):
    occasion: DayOccasion
    dress_level: DayFormality
    note: str | None = None


class DayPlanDayResponse(BaseModel):
    date: dt.date
    # Null = nothing planned that day.
    plan: DayPlanBody | None
    # "day" = the date's own plan; "weekly" = from the weekday's repeat.
    source: DayPlanSource | None
    # A repeat covers this weekday on this date (even when the day has its
    # own override) — the client asks "just this <weekday>, or every one?"
    # when the user edits or clears such a day.
    repeats_weekly: bool


class DayPlansResponse(BaseModel):
    days: list[DayPlanDayResponse]
