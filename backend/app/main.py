from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.api.routes import (
    account,
    analytics,
    auth,
    health,
    outfits,
    profile,
    settings as settings_routes,
    starter_wardrobe,
    support,
    today,
    usage,
    users,
    wardrobe,
    billing,
)
from app.core.config import settings
from app.core.logging import RequestIdMiddleware, bridge_uvicorn_logging, configure_logging

configure_logging(settings)

from app.core import providers as _providers  # noqa: E402,F401  -- import side effect: build & log providers at startup


@asynccontextmanager
async def lifespan(app: FastAPI):
    # uvicorn (re)installs its own log handlers between import-time configure_logging()
    # and the app starting; reset them so all logs flow through structlog.
    bridge_uvicorn_logging()
    yield


app = FastAPI(title=settings.app_name, version=settings.app_version, lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestIdMiddleware)

app.include_router(health.router, prefix=settings.api_v1_prefix)
app.include_router(auth.router, prefix=settings.api_v1_prefix)
app.include_router(users.router, prefix=settings.api_v1_prefix)
app.include_router(profile.router, prefix=settings.api_v1_prefix)
app.include_router(wardrobe.router, prefix=settings.api_v1_prefix)
app.include_router(starter_wardrobe.router, prefix=settings.api_v1_prefix)
app.include_router(today.router, prefix=settings.api_v1_prefix)
app.include_router(outfits.router, prefix=settings.api_v1_prefix)
app.include_router(usage.router, prefix=settings.api_v1_prefix)
app.include_router(analytics.router, prefix=settings.api_v1_prefix)
app.include_router(billing.router, prefix=settings.api_v1_prefix)
app.include_router(settings_routes.router, prefix=settings.api_v1_prefix)
app.include_router(support.router, prefix=settings.api_v1_prefix)
app.include_router(account.router, prefix=settings.api_v1_prefix)

# Dev only: serve the LocalFsStorage upload root so URLs returned by the image
# provider are fetchable. Tbd/prd serves images directly via S3/CloudFront.
if settings.environment == "dev":
    _uploads_root = Path(settings.local_image_dir)
    _uploads_root.mkdir(parents=True, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=str(_uploads_root)), name="uploads")
