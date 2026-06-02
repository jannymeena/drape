from datetime import datetime
from enum import Enum
from uuid import UUID

from pydantic import BaseModel, ConfigDict, EmailStr


class Role(str, Enum):
    customer = "customer"
    admin = "admin"


class UserBase(BaseModel):
    email: EmailStr
    display_name: str


class UserCreate(UserBase):
    pass


class UserUpdate(BaseModel):
    email: EmailStr | None = None
    display_name: str | None = None
    # Profile-tab fields. All optional; `exclude_unset` (in update_user) means an
    # omitted field is left untouched, while an explicit null clears it.
    age_range: str | None = None
    location: str | None = None
    gender: str | None = None
    phone: str | None = None


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    role: Role
    created_at: datetime
    # Profile-tab fields, so the client can rehydrate the Edit Profile form on a
    # fresh install instead of falling back to placeholders.
    age_range: str | None = None
    location: str | None = None
    timezone: str | None = None
    gender: str | None = None
    phone: str | None = None
    shopping_style: str | None = None
    style_goals: list[str] | None = None
