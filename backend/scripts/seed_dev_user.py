"""Seed an idempotent dev user so contributors can `Bearer`-auth without a signup flow.

Usage (from backend/, with the venv active):

    python scripts/seed_dev_user.py

Creates `dev@example.com` / `password` if missing. If the user already exists, this
prints the access token for the existing row instead of failing — safe to re-run.

Refuses to do anything when ENVIRONMENT != dev — never seed predictable credentials
into a tbd/prd database.
"""
from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.core.config import settings  # noqa: E402
from app.core.security import create_access_token  # noqa: E402
from app.db.models import AuthMethod, User  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.schemas.user import Role  # noqa: E402
from app.services.providers.hash.bcrypt import BcryptPasswordHasher  # noqa: E402

DEV_EMAIL = "dev@example.com"
DEV_PASSWORD = "password"
DEV_DISPLAY_NAME = "Dev User"


def main() -> int:
    if settings.environment != "dev":
        print(
            f"refusing to seed: ENVIRONMENT={settings.environment!r} (only 'dev' is allowed)",
            file=sys.stderr,
        )
        return 2

    hasher = BcryptPasswordHasher()
    with SessionLocal() as db:
        user = db.query(User).filter(User.email == DEV_EMAIL).one_or_none()
        if user is None:
            user = User(
                email=DEV_EMAIL,
                display_name=DEV_DISPLAY_NAME,
                role=Role.customer,
                password_hash=hasher.hash(DEV_PASSWORD),
                auth_method=AuthMethod.password,
                agreed_to_terms=True,
                agreed_to_privacy=True,
                terms_agreed_at=datetime.now(timezone.utc),
            )
            db.add(user)
            db.commit()
            db.refresh(user)
            print(f"created dev user: {DEV_EMAIL} / {DEV_PASSWORD} (id={user.id})")
        else:
            print(f"dev user already exists: {DEV_EMAIL} (id={user.id})")

        access = create_access_token(user_id=user.id, role=user.role.value)
        print(f"access_token: {access}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
