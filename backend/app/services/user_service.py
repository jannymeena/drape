from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import User
from app.schemas.user import UserUpdate


def list_users(db: Session) -> list[User]:
    return list(db.scalars(select(User).order_by(User.created_at)).all())


def get_user(db: Session, user_id: UUID) -> User | None:
    return db.get(User, user_id)


def get_user_by_email(db: Session, email: str) -> User | None:
    return db.scalar(select(User).where(User.email == email))


class EmailTakenError(Exception):
    """An update would collide with another user's email. Routes map to 409."""


def update_user(db: Session, user: User, payload: UserUpdate) -> User:
    data = payload.model_dump(exclude_unset=True)
    new_email = data.get("email")
    if new_email is not None and new_email != user.email:
        # Pre-check so a duplicate address returns a clean 409 instead of the
        # DB unique-constraint surfacing as a 500.
        existing = get_user_by_email(db, new_email)
        if existing is not None and existing.id != user.id:
            raise EmailTakenError(new_email)
    # §5.5.1 — consent is flag + timestamp: record when it was granted,
    # clear the timestamp on revoke.
    if data.get("use_measurements_for_fit") is not None:
        granted = bool(data["use_measurements_for_fit"])
        if granted and not user.use_measurements_for_fit:
            user.measurements_fit_consent_at = datetime.now(timezone.utc)
        elif not granted:
            user.measurements_fit_consent_at = None
    for key, value in data.items():
        setattr(user, key, value)
    db.commit()
    db.refresh(user)
    return user


def delete_user(db: Session, user: User) -> None:
    db.delete(user)
    db.commit()
