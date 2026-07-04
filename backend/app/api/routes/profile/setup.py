"""Phase 5a — profile setup routes.

The CTO doc takes user_id in the request bodies; we ignore that and trust the
bearer token instead. Letting the client name a target user invites IDOR.
"""
from __future__ import annotations

import structlog
from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.providers import (
    get_ai_provider,
    get_encryptor,
    get_image_storage,
)
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
from app.services import avatar_analysis, profile_service
from app.services.providers.ai.base import AIProvider
from app.services.providers.crypto.base import Encryptor
from app.services.providers.image.base import ImageStorageProvider

router = APIRouter()

_log = structlog.get_logger("profile.setup")

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
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    encryptor: Encryptor = Depends(get_encryptor),
) -> OnboardingStatusResponse:
    return profile_service.get_status(db, encryptor=encryptor, user=user)


@router.post("/avatar/upload", response_model=UserResponse)
async def upload_avatar(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    storage: ImageStorageProvider = Depends(get_image_storage),
    ai: AIProvider = Depends(get_ai_provider),
) -> UserResponse:
    """Store the user's chosen photo as their avatar and return the refreshed
    user (with `avatar_url`). Reuses the same `ImageStorageProvider` + validation
    limits as wardrobe image upload. Also derives body/skin metadata from the
    photo (§5.5) for outfit personalization — best-effort, never blocks upload."""
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

    # §5.5 — derive body/skin metadata for outfit personalization. The vision
    # call is cached by image hash (§5.1), so re-uploading the same photo is
    # free. Strictly best-effort: a failure must not fail the avatar upload.
    try:
        analysis = await avatar_analysis.analyze_body(
            ai, image_bytes=content, media_type=file.content_type
        )
        if analysis:
            profile_service.set_body_analysis(db, user=user, analysis=analysis)
    except Exception as exc:  # noqa: BLE001 — personalization is non-critical
        _log.warning("profile.avatar.analysis_skipped", error=str(exc))

    return UserResponse.model_validate(user)
