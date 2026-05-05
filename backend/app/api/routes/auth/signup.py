from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.providers import get_password_hasher
from app.db.session import get_db
from app.schemas.auth import SignupRequest, TokenPair
from app.services import auth_service
from app.services.auth_service import AuthError
from app.services.providers.hash.base import PasswordHasher

router = APIRouter()


@router.post("/signup", response_model=TokenPair, status_code=status.HTTP_201_CREATED)
def signup(
    payload: SignupRequest,
    db: Session = Depends(get_db),
    hasher: PasswordHasher = Depends(get_password_hasher),
) -> TokenPair:
    try:
        return auth_service.signup(
            db,
            hasher=hasher,
            email=payload.email,
            password=payload.password,
            display_name=payload.display_name,
            agreed_to_terms=payload.agreed_to_terms,
            agreed_to_privacy=payload.agreed_to_privacy,
        )
    except AuthError as e:
        code = (
            status.HTTP_409_CONFLICT if e.code == "email_taken" else status.HTTP_400_BAD_REQUEST
        )
        raise HTTPException(status_code=code, detail={"code": e.code, "message": str(e)})
