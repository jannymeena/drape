from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.providers import get_oauth_verifier, get_password_hasher
from app.db.session import get_db
from app.schemas.auth import AuthResponse, LoginRequest
from app.services import auth_service
from app.services.auth_service import AuthError
from app.services.providers.hash.base import PasswordHasher
from app.services.providers.oauth.base import OAuthVerifier

router = APIRouter()


@router.post("/login", response_model=AuthResponse)
async def login(
    payload: LoginRequest,
    db: Session = Depends(get_db),
    hasher: PasswordHasher = Depends(get_password_hasher),
    verifier: OAuthVerifier | None = Depends(get_oauth_verifier),
) -> AuthResponse:
    try:
        if payload.auth_method == "email":
            return auth_service.login_email(
                db, hasher=hasher, email=payload.email, password=payload.password
            )
        if verifier is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"code": "oauth_unavailable", "message": "OAuth not enabled in this environment"},
            )
        provider = payload.auth_method  # 'apple' | 'google'
        id_token = payload.apple_id_token if provider == "apple" else payload.google_id_token
        return await auth_service.login_oauth(
            db, verifier=verifier, provider=provider, id_token=id_token
        )
    except AuthError as e:
        if e.code == "inactive":
            code = status.HTTP_403_FORBIDDEN
        elif e.code == "oauth_unavailable":
            code = status.HTTP_400_BAD_REQUEST
        else:
            code = status.HTTP_401_UNAUTHORIZED
        raise HTTPException(status_code=code, detail={"code": e.code, "message": str(e)})
