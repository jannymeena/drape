from fastapi import APIRouter

from app.api.routes.profile import measurements, setup

router = APIRouter(prefix="/profile", tags=["profile"])

router.include_router(setup.router)
router.include_router(measurements.router)
