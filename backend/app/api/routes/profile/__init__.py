from fastapi import APIRouter

from app.api.routes.profile import intelligence, measurements, setup

router = APIRouter(prefix="/profile", tags=["profile"])

router.include_router(setup.router)
router.include_router(measurements.router)
router.include_router(intelligence.router)
