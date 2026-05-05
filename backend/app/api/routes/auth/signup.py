from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.providers import get_oauth_verifier, get_password_hasher
from app.db.session import get_db
from app.schemas.auth import AuthResponse, SignupRequest
from app.services import auth_service
from app.services.auth_service import AuthError
from app.services.providers.hash.base import PasswordHasher
from app.services.providers.oauth.base import OAuthVerifier

router = APIRouter()


@router.post("/signup", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def signup(
    payload: SignupRequest,
    db: Session = Depends(get_db),
    hasher: PasswordHasher = Depends(get_password_hasher),
    verifier: OAuthVerifier | None = Depends(get_oauth_verifier),
) -> AuthResponse:
    try:
        if payload.auth_method == "email":
            return auth_service.signup_email(
                db,
                hasher=hasher,
                email=payload.email,
                password=payload.password,
                display_name=payload.display_name,
                agreed_to_terms=payload.agreed_to_terms,
                agreed_to_privacy=payload.agreed_to_privacy,
            )
        if verifier is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail={"code": "oauth_unavailable", "message": "OAuth not enabled in this environment"},
            )
        provider = payload.auth_method  # 'apple' | 'google'
        id_token = payload.apple_id_token if provider == "apple" else payload.google_id_token
        return await auth_service.signup_oauth(
            db,
            verifier=verifier,
            provider=provider,
            id_token=id_token,
            agreed_to_terms=payload.agreed_to_terms,
            agreed_to_privacy=payload.agreed_to_privacy,
        )
    except AuthError as e:
        if e.code == "email_already_exists":
            code = status.HTTP_400_BAD_REQUEST
        elif e.code == "consent_required":
            code = status.HTTP_400_BAD_REQUEST
        else:
            code = status.HTTP_401_UNAUTHORIZED
        raise HTTPException(status_code=code, detail={"code": e.code, "message": str(e)})
