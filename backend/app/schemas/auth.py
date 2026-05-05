import re
from typing import Literal
from uuid import UUID

from pydantic import BaseModel, EmailStr, Field, model_validator

PASSWORD_RE = re.compile(r"^(?=.*[A-Za-z])(?=.*\d).{8,128}$")
PASSWORD_RULE_MSG = "Password must be 8-128 characters with at least one letter and one number"


class _PasswordMixin:
    @staticmethod
    def _check_password(value: str) -> str:
        if not PASSWORD_RE.match(value):
            raise ValueError(PASSWORD_RULE_MSG)
        return value


AuthMethodLiteral = Literal["email", "apple", "google"]


class SignupRequest(BaseModel):
    auth_method: AuthMethodLiteral
    email: EmailStr | None = None
    password: str | None = None
    display_name: str | None = Field(default=None, max_length=120)
    apple_id_token: str | None = None
    google_id_token: str | None = None
    agreed_to_terms: bool
    agreed_to_privacy: bool

    @model_validator(mode="after")
    def _validate(self) -> "SignupRequest":
        if self.auth_method == "email":
            if not self.email or not self.password or not self.display_name:
                raise ValueError("email, password, and display_name are required for email signup")
            if not PASSWORD_RE.match(self.password):
                raise ValueError(PASSWORD_RULE_MSG)
        elif self.auth_method == "apple" and not self.apple_id_token:
            raise ValueError("apple_id_token is required for Apple signup")
        elif self.auth_method == "google" and not self.google_id_token:
            raise ValueError("google_id_token is required for Google signup")
        return self


class LoginRequest(BaseModel):
    auth_method: AuthMethodLiteral
    email: EmailStr | None = None
    password: str | None = None
    apple_id_token: str | None = None
    google_id_token: str | None = None

    @model_validator(mode="after")
    def _validate(self) -> "LoginRequest":
        if self.auth_method == "email":
            if not self.email or not self.password:
                raise ValueError("email and password are required for email login")
        elif self.auth_method == "apple" and not self.apple_id_token:
            raise ValueError("apple_id_token is required for Apple login")
        elif self.auth_method == "google" and not self.google_id_token:
            raise ValueError("google_id_token is required for Google login")
        return self


class RefreshRequest(BaseModel):
    refresh_token: str


class LogoutRequest(BaseModel):
    refresh_token: str


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPasswordRequest(BaseModel):
    token: str
    new_password: str = Field(min_length=8, max_length=128)

    @model_validator(mode="after")
    def _validate(self) -> "ResetPasswordRequest":
        if not PASSWORD_RE.match(self.new_password):
            raise ValueError(PASSWORD_RULE_MSG)
        return self


class AuthResponse(BaseModel):
    """Returned by signup, login, and refresh — matches the CTO doc shape."""

    user_id: UUID
    email: EmailStr
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    onboarding_completed: bool
    next_step: str
