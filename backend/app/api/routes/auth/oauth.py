from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.providers import get_oauth_verifier
from app.db.session import get_db
from app.schemas.auth import OAuthLoginRequest, TokenPair
from app.services import auth_service
from app.services.auth_service import AuthError
from app.services.providers.oauth.base import OAuthVerifier

router = APIRouter(prefix="/oauth")


def _require_verifier(
    verifier: OAuthVerifier | None = Depends(get_oauth_verifier),
) -> OAuthVerifier:
    if verifier is None:
        # This route shouldn't be mounted in dev — guard anyway.
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="OAuth disabled in this environment"
        )
    return verifier


@router.post("/apple", response_model=TokenPair)
async def apple_login(
    payload: OAuthLoginRequest,
    db: Session = Depends(get_db),
    verifier: OAuthVerifier = Depends(_require_verifier),
) -> TokenPair:
    try:
        return await auth_service.oauth_login(
            db, verifier=verifier, provider="apple", id_token=payload.id_token
        )
    except AuthError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": e.code, "message": str(e)},
        )


@router.post("/google", response_model=TokenPair)
async def google_login(
    payload: OAuthLoginRequest,
    db: Session = Depends(get_db),
    verifier: OAuthVerifier = Depends(_require_verifier),
) -> TokenPair:
    try:
        return await auth_service.oauth_login(
            db, verifier=verifier, provider="google", id_token=payload.id_token
        )
    except AuthError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail={"code": e.code, "message": str(e)},
        )
