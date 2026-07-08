"""Account-level operations: data export (PIPEDA access request) + self-delete."""
from __future__ import annotations

import structlog
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import Outfit, User, WardrobeItem
from app.schemas.settings import SettingsResponse
from app.services import measurements_service, settings_service
from app.services.providers.crypto.base import Encryptor

_log = structlog.get_logger("account")


def export_user_data(db: Session, *, user: User, encryptor: Encryptor) -> dict:
    """A portable JSON snapshot of everything we hold for the user. Measurements
    are decrypted for the export (it's the user's own data, access-controlled)."""
    settings = settings_service.get_or_create(db, user=user)
    measurements = measurements_service.get_for_user(db, encryptor=encryptor, user=user)
    items = list(
        db.scalars(select(WardrobeItem).where(WardrobeItem.user_id == user.id)).all()
    )
    outfit_count = int(
        db.scalar(select(func.count(Outfit.id)).where(Outfit.user_id == user.id)) or 0
    )

    return {
        "account": {
            "id": str(user.id),
            "email": user.email,
            "display_name": user.display_name,
            "created_at": user.created_at.isoformat() if user.created_at else None,
            "shopping_style": user.shopping_style,
            "age_range": user.age_range,
            "style_goals": user.style_goals,
            "gender": user.gender,
            "phone": user.phone,
            "location": user.location,
            "timezone": user.timezone,
            "avatar_url": user.avatar_url,
            "community_share_avatar": user.community_share_avatar,
            "use_measurements_for_fit": user.use_measurements_for_fit,
            "measurements_fit_consent_at": (
                user.measurements_fit_consent_at.isoformat()
                if user.measurements_fit_consent_at
                else None
            ),
        },
        "settings": SettingsResponse.model_validate(settings).model_dump(),
        "measurements": measurements.model_dump() if measurements else None,
        "wardrobe": [
            {
                "name": i.name,
                "category": i.category,
                "color_name": i.color_name,
                "pattern": i.pattern,
                "formality": i.formality,
                "is_starter_wardrobe": i.is_starter_wardrobe,
                "worn_count": i.worn_count,
                "created_at": i.created_at.isoformat() if i.created_at else None,
            }
            for i in items
        ],
        "stats": {"wardrobe_items": len(items), "outfits_generated": outfit_count},
    }


def delete_account(db: Session, *, user: User) -> None:
    """Hard-delete the user. FK cascades remove profile, settings, measurements
    (including the derived fit profile — the §5.5.1 purge requirement),
    wardrobe, outfits, tokens, tickets, etc."""
    _log.info("account.deleted", user_id=str(user.id))
    db.delete(user)
    db.commit()
