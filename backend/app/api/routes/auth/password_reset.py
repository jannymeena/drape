from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.api.dependencies.providers import get_email_provider, get_password_hasher
from app.db.session import get_db
from app.schemas.auth import ForgotPasswordRequest, ResetPasswordRequest
from app.services import auth_service
from app.services.auth_service import AuthError
from app.services.providers.email.base import EmailProvider
from app.services.providers.hash.base import PasswordHasher

router = APIRouter()


@router.post("/forgot-password", status_code=status.HTTP_202_ACCEPTED)
async def forgot_password(
    payload: ForgotPasswordRequest,
    db: Session = Depends(get_db),
    email_provider: EmailProvider = Depends(get_email_provider),
) -> dict[str, str]:
    await auth_service.forgot_password(
        db, email_provider=email_provider, email=payload.email
    )
    # Always return the same body — never confirm whether the email exists.
    return {"status": "ok"}


@router.post("/reset-password", status_code=status.HTTP_204_NO_CONTENT)
def reset_password(
    payload: ResetPasswordRequest,
    db: Session = Depends(get_db),
    hasher: PasswordHasher = Depends(get_password_hasher),
) -> None:
    try:
        auth_service.reset_password(
            db, hasher=hasher, raw_token=payload.token, new_password=payload.new_password
        )
    except AuthError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"code": e.code, "message": str(e)},
        )
