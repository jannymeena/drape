"""Day plans — Plan your week / Plan a day.

  - GET    /today/plans?from=&to=   resolved days (default: the next 7)
  - PUT    /today/plans/{date}      save a day (scope=day | from_now)
  - DELETE /today/plans/{date}      clear a day (scope=day | from_now)

See `app/services/day_plan_service.py` for how a day resolves and what each
scope does.
"""
from __future__ import annotations

import datetime as dt

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.day_plan import (
    DayPlanBody,
    DayPlanDayResponse,
    DayPlanScope,
    DayPlansResponse,
    DayPlanUpsertRequest,
)
from app.services import day_plan_service
from app.services.day_plan_service import DayPlanError, ResolvedDay

router = APIRouter(prefix="/today/plans", tags=["today"])


def to_day_response(day: ResolvedDay) -> DayPlanDayResponse:
    return DayPlanDayResponse(
        date=day.date,
        plan=(
            DayPlanBody(occasion=day.occasion, dress_level=day.dress_level, note=day.note)
            if day.has_plan
            else None
        ),
        source=day.source,
        repeats_weekly=day.repeats_weekly,
    )


def _translate(err: DayPlanError) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
        detail={"error": err.code, "message": str(err)},
    )


@router.get("", response_model=DayPlansResponse)
def list_plans(
    from_: dt.date | None = Query(default=None, alias="from"),
    to: dt.date | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DayPlansResponse:
    """Every day in the range with its plan, or null when nothing's planned."""
    try:
        days = day_plan_service.resolve_range(db, user=user, start=from_, end=to)
    except DayPlanError as e:
        raise _translate(e)
    return DayPlansResponse(days=[to_day_response(d) for d in days])


@router.put("/{plan_date}", response_model=DayPlanDayResponse)
def save_plan(
    plan_date: dt.date,
    payload: DayPlanUpsertRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DayPlanDayResponse:
    """scope=day — just this date (with `until`: each same-weekday date up to
    it, then the repeat resumes). scope=from_now — this weekday repeats the
    plan from this date on (with `until`: up to that date)."""
    try:
        day = day_plan_service.save(
            db,
            user=user,
            day=plan_date,
            occasion=payload.occasion,
            dress_level=payload.dress_level,
            note=payload.note,
            scope=payload.scope,
            until=payload.until,
        )
    except DayPlanError as e:
        raise _translate(e)
    return to_day_response(day)


@router.delete("/{plan_date}", response_model=DayPlanDayResponse)
def clear_plan(
    plan_date: dt.date,
    scope: DayPlanScope = "day",
    until: dt.date | None = None,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> DayPlanDayResponse:
    """scope=day — clear just this date (with `until`: each same-weekday date
    up to it). scope=from_now — stop this weekday's repeat from this date on."""
    try:
        day = day_plan_service.clear(
            db, user=user, day=plan_date, scope=scope, until=until
        )
    except DayPlanError as e:
        raise _translate(e)
    return to_day_response(day)
