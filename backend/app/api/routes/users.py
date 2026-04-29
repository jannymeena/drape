from datetime import datetime, timezone

from fastapi import APIRouter, status

from app.schemas.user import Role, UserCreate, UserResponse, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])

_FIXED_TIME = datetime(2026, 1, 1, tzinfo=timezone.utc)


def _fake_user(user_id: int, email: str, display_name: str, role: Role = Role.customer) -> UserResponse:
    return UserResponse(
        id=user_id,
        email=email,
        display_name=display_name,
        role=role,
        created_at=_FIXED_TIME,
    )


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(payload: UserCreate) -> UserResponse:
    return _fake_user(1, payload.email, payload.display_name)


@router.get("", response_model=list[UserResponse])
async def list_users() -> list[UserResponse]:
    return [
        _fake_user(1, "alice@example.com", "Alice", Role.admin),
        _fake_user(2, "bob@example.com", "Bob"),
    ]


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: int) -> UserResponse:
    return _fake_user(user_id, "test@example.com", "Test User")


@router.patch("/{user_id}", response_model=UserResponse)
async def update_user(user_id: int, payload: UserUpdate) -> UserResponse:
    return _fake_user(
        user_id,
        payload.email or "test@example.com",
        payload.display_name or "Test User",
    )


@router.delete("/{user_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_user(user_id: int) -> None:
    return None
