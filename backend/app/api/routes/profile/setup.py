"""Phase 5a — profile setup routes.

The CTO doc takes user_id in the request bodies; we ignore that and trust the
bearer token instead. Letting the client name a target user invites IDOR.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.profile import (
    OnboardingStatusResponse,
    ProfileAgeRangeRequest,
    ProfileShoppingStyleRequest,
    ProfileStepResponse,
    ProfileStyleGoalsRequest,
    SaveProgressRequest,
)
from app.services import profile_service

router = APIRouter()


@router.post("/shopping-style", response_model=ProfileStepResponse)
def set_shopping_style(
    payload: ProfileShoppingStyleRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ProfileStepResponse:
    nxt = profile_service.set_shopping_style(db, user=user, payload=payload)
    return ProfileStepResponse(next_step=nxt)


@router.post("/age-range", response_model=ProfileStepResponse)
def set_age_range(
    payload: ProfileAgeRangeRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ProfileStepResponse:
    nxt = profile_service.set_age_range(db, user=user, payload=payload)
    return ProfileStepResponse(next_step=nxt)


@router.post("/style-goals", response_model=ProfileStepResponse)
def set_style_goals(
    payload: ProfileStyleGoalsRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ProfileStepResponse:
    nxt = profile_service.set_style_goals(db, user=user, payload=payload)
    return ProfileStepResponse(next_step=nxt)


@router.post("/save-progress", response_model=ProfileStepResponse)
def save_progress(
    payload: SaveProgressRequest,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> ProfileStepResponse:
    nxt = profile_service.save_progress(db, user=user, payload=payload)
    return ProfileStepResponse(next_step=nxt)


@router.get("/onboarding-status", response_model=OnboardingStatusResponse)
def get_onboarding_status(
    user: User = Depends(get_current_user),
) -> OnboardingStatusResponse:
    return profile_service.get_status(user)
