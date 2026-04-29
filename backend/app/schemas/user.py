from datetime import datetime
from enum import Enum

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


class UserResponse(UserBase):
    model_config = ConfigDict(from_attributes=True)

    id: int
    role: Role
    created_at: datetime
