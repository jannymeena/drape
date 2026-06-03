"""User settings — get-or-create 1:1 row, then partial update."""
from __future__ import annotations

from sqlalchemy.orm import Session

from app.db.models import User, UserSettings
from app.schemas.settings import SettingsUpdate


def get_or_create(db: Session, *, user: User) -> UserSettings:
    settings = user.settings
    if settings is None:
        settings = UserSettings(user_id=user.id)
        db.add(settings)
        db.commit()
        db.refresh(settings)
    return settings


def update(db: Session, *, user: User, payload: SettingsUpdate) -> UserSettings:
    settings = get_or_create(db, user=user)
    for key, value in payload.model_dump(exclude_unset=True).items():
        setattr(settings, key, value)
    db.commit()
    db.refresh(settings)
    return settings
