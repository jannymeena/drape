from uuid import UUID

import structlog
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.security import InvalidToken, decode_access_token
from app.db.models import User
from app.db.session import get_db
from app.schemas.user import Role

_security = HTTPBearer(auto_error=False)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_security),
    db: Session = Depends(get_db),
) -> User:
    # Async on purpose (the body is cheap sync work): a sync dependency runs
    # in a threadpool with a *copied* context, so the user_id bound below
    # would never reach the request middleware's completion event.
    if creds is None:
        raise _unauthorized("Missing bearer token")
    try:
        payload = decode_access_token(creds.credentials)
    except InvalidToken:
        raise _unauthorized("Invalid or expired token")

    try:
        user_id = UUID(payload["sub"])
    except (KeyError, ValueError):
        raise _unauthorized("Invalid token payload")

    user = db.get(User, user_id)
    if user is None or not user.is_active:
        raise _unauthorized("User not found or inactive")
    # From here every log line in this request — domain events and the
    # middleware's request.completed — carries the caller's user_id.
    structlog.contextvars.bind_contextvars(user_id=str(user.id))
    return user


def require_role(*roles: Role):
    def checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return user

    return checker
