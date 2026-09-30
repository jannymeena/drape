import asyncio
import contextlib
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
    devices,
    shop,
)
from app.core.config import settings
from app.core.logging import RequestIdMiddleware, bridge_uvicorn_logging, configure_logging

configure_logging(settings)

from app.core import providers as _providers  # noqa: E402,F401  -- import side effect: build & log providers at startup


def _start_catalog_worker() -> asyncio.Task | None:
    if not settings.catalog_worker_enabled:
        return None
    from app.core.providers import providers
    from app.db.session import SessionLocal
    from app.workers.catalog_worker import CatalogWorker

    worker = CatalogWorker(
        session_factory=SessionLocal,
        affiliate=providers.affiliate,
        ai=providers.ai,
        tag_model=settings.catalog_tag_model,
        advertiser_genders=settings.advertiser_genders(),
    )
    return asyncio.create_task(worker.run(), name="catalog-worker")


def _start_trend_worker() -> asyncio.Task | None:
    # Web research needs the real provider; the mock can't search.
    if not settings.trend_worker_enabled or not settings.anthropic_api_key:
        return None
    from app.core.providers import providers
    from app.db.session import SessionLocal
    from app.workers.trend_worker import TrendWorker

    worker = TrendWorker(
        session_factory=SessionLocal, ai=providers.ai, model=settings.ai_trend_model
    )
    return asyncio.create_task(worker.run(), name="trend-worker")


@asynccontextmanager
async def lifespan(app: FastAPI):
    # uvicorn (re)installs its own log handlers between import-time configure_logging()
    # and the app starting; reset them so all logs flow through structlog.
    bridge_uvicorn_logging()
    tasks = [t for t in (_start_catalog_worker(), _start_trend_worker()) if t is not None]
    yield
    for task in tasks:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


app = FastAPI(title=settings.app_name, version=settings.app_version, lifespan=lifespan)

# CORS only exists for browser clients; the mobile app never preflights. Dev
# defaults to "*" (local web tools); tbd/prd default to no CORS middleware at
# all until CORS_ALLOW_ORIGINS lists a real web origin. Credentials are only
# allowed when origins are explicit — the "*" + credentials combination is
# rejected by browsers anyway.
_cors_origins = settings.cors_origin_list
if _cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=_cors_origins,
        allow_credentials="*" not in _cors_origins,
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
app.include_router(devices.router, prefix=settings.api_v1_prefix)
app.include_router(shop.router, prefix=settings.api_v1_prefix)
app.include_router(settings_routes.router, prefix=settings.api_v1_prefix)
app.include_router(support.router, prefix=settings.api_v1_prefix)
app.include_router(account.router, prefix=settings.api_v1_prefix)

# Dev only: serve the LocalFsStorage upload root so URLs returned by the image
# provider are fetchable. Tbd/prd serves images directly via S3/CloudFront.
if settings.environment == "dev":
    _uploads_root = Path(settings.local_image_dir)
    _uploads_root.mkdir(parents=True, exist_ok=True)
    app.mount("/uploads", StaticFiles(directory=str(_uploads_root)), name="uploads")
