"""Profile-tab intelligence stats (item 8a) — GET /profile/intelligence.

Free-tier visible: these are the headline numbers on the Profile screen; the
Pro-gated deep report lives at /wardrobe/analytics/intelligence-report.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.analytics import ProfileIntelligence
from app.services import analytics_service

router = APIRouter()


@router.get("/intelligence", response_model=ProfileIntelligence)
def profile_intelligence(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ProfileIntelligence:
    return analytics_service.profile_intelligence(db, user=user)
