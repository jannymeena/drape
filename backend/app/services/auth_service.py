from datetime import datetime, timezone
from typing import Literal

import structlog
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.security import (
    create_access_token,
    generate_opaque_token,
    hash_opaque_token,
    password_reset_expiry,
    refresh_token_expiry,
)
from app.db.models import AuthMethod, PasswordResetToken, RefreshToken, User
from app.schemas.auth import AuthResponse
from app.schemas.user import Role
from app.services.profile_service import next_step as onboarding_next_step
from app.services.providers.email.base import EmailProvider
from app.services.providers.hash.base import PasswordHasher
from app.services.providers.oauth.base import OAuthVerifier

_log = structlog.get_logger("auth")


class AuthError(Exception):
    """Domain-level auth failure. Routes translate to 4xx."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _build_response(db: Session, user: User) -> AuthResponse:
    access = create_access_token(user_id=user.id, role=user.role.value)
    raw_refresh, hashed = generate_opaque_token()
    db.add(
        RefreshToken(
            user_id=user.id,
            token_hash=hashed,
            expires_at=refresh_token_expiry(),
            created_at=_now(),
        )
    )
    db.commit()
    return AuthResponse(
        user_id=user.id,
        email=user.email,
        access_token=access,
        refresh_token=raw_refresh,
        onboarding_completed=user.onboarding_completed,
        next_step=onboarding_next_step(user),
    )


def signup_email(
    db: Session,
    *,
    hasher: PasswordHasher,
    email: str,
    password: str,
    display_name: str,
    agreed_to_terms: bool,
    agreed_to_privacy: bool,
) -> AuthResponse:
    if not agreed_to_terms or not agreed_to_privacy:
        raise AuthError("consent_required", "Must agree to terms and privacy policy")

    user = User(
        email=email,
        display_name=display_name,
        role=Role.customer,
        password_hash=hasher.hash(password),
        auth_method=AuthMethod.email,
        agreed_to_terms=True,
        agreed_to_privacy=True,
        terms_agreed_at=_now(),
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise AuthError("email_already_exists", "Email already registered")
    db.refresh(user)
    _log.info("auth.signup.email", user_id=str(user.id), email=email)
    return _build_response(db, user)


async def signup_oauth(
    db: Session,
    *,
    verifier: OAuthVerifier,
    provider: Literal["apple", "google"],
    id_token: str,
    agreed_to_terms: bool,
    agreed_to_privacy: bool,
) -> AuthResponse:
    if not agreed_to_terms or not agreed_to_privacy:
        raise AuthError("consent_required", "Must agree to terms and privacy policy")
    user = await _upsert_oauth_user(db, verifier=verifier, provider=provider, id_token=id_token)
    _log.info("auth.signup.oauth", user_id=str(user.id), provider=provider)
    return _build_response(db, user)


def login_email(
    db: Session,
    *,
    hasher: PasswordHasher,
    email: str,
    password: str,
) -> AuthResponse:
    user = db.scalar(select(User).where(User.email == email))
    # Constant message regardless of which check fails — don't leak which emails exist.
    if user is None or not user.password_hash or not hasher.verify(password, user.password_hash):
        raise AuthError("invalid_credentials", "Invalid email or password")
    if not user.is_active:
        raise AuthError("inactive", "Account is inactive")
    _log.info("auth.login.email", user_id=str(user.id))
    return _build_response(db, user)


async def login_oauth(
    db: Session,
    *,
    verifier: OAuthVerifier,
    provider: Literal["apple", "google"],
    id_token: str,
) -> AuthResponse:
    # OAuth login is functionally identical to OAuth signup — verify, get-or-create, issue.
    # The client picks signup vs login based on which screen fired, but the server treats
    # both as idempotent.
    user = await _upsert_oauth_user(db, verifier=verifier, provider=provider, id_token=id_token)
    _log.info("auth.login.oauth", user_id=str(user.id), provider=provider)
    return _build_response(db, user)


async def _upsert_oauth_user(
    db: Session,
    *,
    verifier: OAuthVerifier,
    provider: Literal["apple", "google"],
    id_token: str,
) -> User:
    if provider == "apple":
        claims = await verifier.verify_apple(id_token)
        oauth_id_field = "apple_id"
        method = AuthMethod.apple
    else:
        claims = await verifier.verify_google(id_token)
        oauth_id_field = "google_id"
        method = AuthMethod.google

    sub = claims.get("sub")
    email = claims.get("email")
    if not sub or not email:
        raise AuthError("oauth_missing_claims", "OAuth provider did not return sub/email")

    user = db.scalar(select(User).where(getattr(User, oauth_id_field) == sub))
    if user is None:
        # Try to link by email if a password account already exists at the same address.
        user = db.scalar(select(User).where(User.email == email))
        if user is None:
            user = User(
                email=email,
                display_name=claims.get("name") or email.split("@")[0],
                role=Role.customer,
                auth_method=method,
                agreed_to_terms=True,
                agreed_to_privacy=True,
                terms_agreed_at=_now(),
            )
            setattr(user, oauth_id_field, sub)
            db.add(user)
        else:
            setattr(user, oauth_id_field, sub)
        db.commit()
        db.refresh(user)
    if not user.is_active:
        raise AuthError("inactive", "Account is inactive")
    return user


def refresh(db: Session, *, raw_refresh: str) -> AuthResponse:
    hashed = hash_opaque_token(raw_refresh)
    row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == hashed))
    if row is None or row.revoked_at is not None or row.expires_at <= _now():
        raise AuthError("invalid_refresh", "Refresh token is invalid or expired")
    user = db.get(User, row.user_id)
    if user is None or not user.is_active:
        raise AuthError("invalid_refresh", "Refresh token is invalid or expired")
    # Rotate: revoke the old, issue a new pair.
    row.revoked_at = _now()
    db.commit()
    return _build_response(db, user)


def logout(db: Session, *, raw_refresh: str) -> None:
    hashed = hash_opaque_token(raw_refresh)
    row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == hashed))
    if row is None or row.revoked_at is not None:
        return  # idempotent
    row.revoked_at = _now()
    db.commit()


async def forgot_password(
    db: Session,
    *,
    email_provider: EmailProvider,
    email: str,
) -> None:
    user = db.scalar(select(User).where(User.email == email))
    if user is None:
        # Don't leak which emails exist.
        _log.info("auth.forgot_password.unknown_email", email=email)
        return
    raw, hashed = generate_opaque_token()
    db.add(
        PasswordResetToken(
            user_id=user.id,
            token_hash=hashed,
            expires_at=password_reset_expiry(),
            created_at=_now(),
        )
    )
    db.commit()

    reset_url = settings.password_reset_url_template.format(token=raw)
    await email_provider.send(
        to=email,
        subject="Drape — reset your password",
        body=f"Reset your password with this link (valid 30 minutes): {reset_url}",
    )
    _log.info("auth.forgot_password.sent", user_id=str(user.id))


def reset_password(
    db: Session,
    *,
    hasher: PasswordHasher,
    raw_token: str,
    new_password: str,
) -> None:
    hashed = hash_opaque_token(raw_token)
    row = db.scalar(select(PasswordResetToken).where(PasswordResetToken.token_hash == hashed))
    if row is None or row.used_at is not None or row.expires_at <= _now():
        raise AuthError("invalid_reset_token", "Reset token is invalid or expired")
    user = db.get(User, row.user_id)
    if user is None:
        raise AuthError("invalid_reset_token", "Reset token is invalid or expired")
    user.password_hash = hasher.hash(new_password)
    row.used_at = _now()
    # Invalidate all live refresh tokens for this user — password changed.
    db.query(RefreshToken).filter(
        RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None)
    ).update({RefreshToken.revoked_at: _now()})
    db.commit()
    _log.info("auth.reset_password", user_id=str(user.id))
