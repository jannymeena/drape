from fastapi import APIRouter

from app.api.routes.auth import login, oauth, password_reset, signup, tokens
from app.core.config import settings

router = APIRouter(prefix="/auth", tags=["auth"])

router.include_router(signup.router)
router.include_router(login.router)
router.include_router(tokens.router)
router.include_router(password_reset.router)

# OAuth uses the (real-impl-only) `OAuthVerifier`. In dev there is no verifier, so the
# routes would 500 on call — better to not mount them at all.
if settings.environment != "dev":
    router.include_router(oauth.router)
