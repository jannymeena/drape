"""Phase 6d — wardrobe analytics routes.

Four reports under `/wardrobe/analytics`:
  * cost-per-wear        free
  * utilization-score    free
  * weekly-report        free (teaser)
  * intelligence-report  Pro-only (gated by require_pro → 402)
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.billing import require_pro
from app.db.models import User
from app.db.session import get_db
from app.schemas.analytics import (
    CostPerWearReport,
    IntelligenceReport,
    UtilizationScore,
    WeeklyReport,
)
from app.services import analytics_service

router = APIRouter(prefix="/wardrobe/analytics", tags=["analytics"])


@router.get("/cost-per-wear", response_model=CostPerWearReport)
def cost_per_wear(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> CostPerWearReport:
    return analytics_service.cost_per_wear(db, user=user)


@router.get("/utilization-score", response_model=UtilizationScore)
def utilization_score(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> UtilizationScore:
    return analytics_service.utilization_score(db, user=user)


@router.get("/weekly-report", response_model=WeeklyReport)
def weekly_report(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> WeeklyReport:
    return analytics_service.weekly_report(db, user=user)


@router.get("/intelligence-report", response_model=IntelligenceReport)
def intelligence_report(
    db: Session = Depends(get_db),
    user: User = Depends(require_pro),  # 402 for free users
) -> IntelligenceReport:
    return analytics_service.intelligence_report(db, user=user)
