from datetime import datetime, timedelta, timezone
from typing import Any
from uuid import UUID

import jwt

from app.core.config import settings


class InvalidToken(Exception):
    pass


def create_access_token(*, user_id: UUID, role: str, extra: dict[str, Any] | None = None) -> str:
    now = datetime.now(timezone.utc)
    payload: dict[str, Any] = {
        "sub": str(user_id),
        "role": role,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=settings.jwt_access_ttl_minutes)).timestamp()),
        "type": "access",
    }
    if extra:
        payload.update(extra)
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def create_refresh_token(*, user_id: UUID) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(user_id),
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(days=settings.jwt_refresh_ttl_days)).timestamp()),
        "type": "refresh",
    }
    return jwt.encode(payload, settings.jwt_secret, algorithm="HS256")


def decode_token(token: str) -> dict[str, Any]:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=["HS256"])
    except jwt.PyJWTError as e:
        raise InvalidToken(str(e)) from e
