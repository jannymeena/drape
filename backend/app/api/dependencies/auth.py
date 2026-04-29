from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.core.config import settings
from app.db.models import User
from app.db.session import get_db
from app.schemas.user import Role

MOCK_UID = "mock_local_user"
MOCK_EMAIL = "local-dev@example.com"
MOCK_DISPLAY_NAME = "Local Dev"

_security = HTTPBearer(auto_error=False)
_firebase_initialized = False


def _ensure_firebase() -> None:
    global _firebase_initialized
    if _firebase_initialized:
        return
    import firebase_admin
    from firebase_admin import credentials

    if not settings.firebase_credentials_path:
        raise RuntimeError(
            "FIREBASE_CREDENTIALS_PATH must be set when ENVIRONMENT is not 'local'"
        )
    if not firebase_admin._apps:
        firebase_admin.initialize_app(credentials.Certificate(settings.firebase_credentials_path))
    _firebase_initialized = True


def _get_or_create_user(db: Session, *, firebase_uid: str, email: str, display_name: str) -> User:
    user = db.query(User).filter(User.firebase_uid == firebase_uid).one_or_none()
    if user is None:
        user = User(
            firebase_uid=firebase_uid,
            email=email,
            display_name=display_name,
            role=Role.customer,
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user


def get_current_user(
    creds: HTTPAuthorizationCredentials | None = Depends(_security),
    db: Session = Depends(get_db),
) -> User:
    if settings.environment == "local":
        return _get_or_create_user(
            db,
            firebase_uid=MOCK_UID,
            email=MOCK_EMAIL,
            display_name=MOCK_DISPLAY_NAME,
        )

    if creds is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing bearer token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    _ensure_firebase()
    from firebase_admin import auth as firebase_auth

    try:
        decoded = firebase_auth.verify_id_token(creds.credentials)
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )

    return _get_or_create_user(
        db,
        firebase_uid=decoded["uid"],
        email=decoded.get("email") or f"{decoded['uid']}@unknown",
        display_name=decoded.get("name") or decoded.get("email") or decoded["uid"],
    )


def require_role(*roles: Role):
    def checker(user: User = Depends(get_current_user)) -> User:
        if user.role not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden")
        return user

    return checker
