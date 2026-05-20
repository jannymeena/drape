"""Phase 6d — usage summary endpoint.

`/usage/current-week` is a read-only snapshot. Increment-and-check happens at
the action endpoints (today.py, outfits.py); this route is purely for the
client to render usage banners (75% / 90% / 100%) and the countdown timer.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.usage import CurrentWeekUsage
from app.services import usage_service

router = APIRouter(prefix="/usage", tags=["usage"])


@router.get("/current-week", response_model=CurrentWeekUsage)
def current_week(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CurrentWeekUsage:
    return usage_service.get_summary(db, user=user)
