"""Phase 8c — user settings (notifications + appearance + units + style)."""
from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api.dependencies.auth import get_current_user
from app.db.models import User
from app.db.session import get_db
from app.schemas.settings import SettingsResponse, SettingsUpdate
from app.services import settings_service

router = APIRouter(prefix="/settings", tags=["settings"])


@router.get("", response_model=SettingsResponse)
def get_settings(
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SettingsResponse:
    return SettingsResponse.model_validate(settings_service.get_or_create(db, user=user))


@router.patch("", response_model=SettingsResponse)
def update_settings(
    payload: SettingsUpdate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> SettingsResponse:
    return SettingsResponse.model_validate(
        settings_service.update(db, user=user, payload=payload)
    )
