from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.providers import get_password_hasher
from app.db.session import get_db
from app.schemas.auth import LoginRequest, TokenPair
from app.services import auth_service
from app.services.auth_service import AuthError
from app.services.providers.hash.base import PasswordHasher

router = APIRouter()


@router.post("/login", response_model=TokenPair)
def login(
    payload: LoginRequest,
    db: Session = Depends(get_db),
    hasher: PasswordHasher = Depends(get_password_hasher),
) -> TokenPair:
    try:
        return auth_service.login(
            db, hasher=hasher, email=payload.email, password=payload.password
        )
    except AuthError as e:
        code = (
            status.HTTP_403_FORBIDDEN if e.code == "inactive" else status.HTTP_401_UNAUTHORIZED
        )
        raise HTTPException(status_code=code, detail={"code": e.code, "message": str(e)})
