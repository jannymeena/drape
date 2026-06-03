"""Phase 5a — profile setup routes.

The CTO doc takes user_id in the request bodies; we ignore that and trust the
bearer token instead. Letting the client name a target user invites IDOR.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.providers import get_image_storage
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
from app.schemas.user import UserResponse
from app.services import profile_service
from app.services.providers.image.base import ImageStorageProvider

router = APIRouter()

_ALLOWED_AVATAR_TYPES = {"image/jpeg", "image/png", "image/webp"}
_MAX_AVATAR_BYTES = 8 * 1024 * 1024  # 8 MiB, matches the wardrobe image cap.


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


@router.post("/avatar/upload", response_model=UserResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    storage: ImageStorageProvider = Depends(get_image_storage),
) -> UserResponse:
    """Store the user's chosen photo as their avatar and return the refreshed
    user (with `avatar_url`). Reuses the same `ImageStorageProvider` + validation
    limits as wardrobe image upload."""
    if file.content_type not in _ALLOWED_AVATAR_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported content type {file.content_type!r}; "
            f"expected one of {sorted(_ALLOWED_AVATAR_TYPES)}",
        )
    content = await file.read()
    if len(content) == 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Empty file upload"
        )
    if len(content) > _MAX_AVATAR_BYTES:
        raise HTTPException(
            status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
            detail=f"File exceeds {_MAX_AVATAR_BYTES} bytes",
        )
    profile_service.set_avatar(
        db, user=user, storage=storage, content=content, content_type=file.content_type
    )
    return UserResponse.model_validate(user)
