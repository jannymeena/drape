from fastapi import APIRouter

from app.api.routes.auth import login, password_reset, signup, tokens

router = APIRouter(prefix="/auth", tags=["auth"])

router.include_router(signup.router)
router.include_router(login.router)
router.include_router(tokens.router)
router.include_router(password_reset.router)
