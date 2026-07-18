import logging
import sys
import time
import uuid

import structlog
from starlette.datastructures import Headers, MutableHeaders

from app.core.config import Settings


def configure_logging(settings: Settings) -> None:
    timestamper = structlog.processors.TimeStamper(fmt="iso")

    shared_processors: list = [
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.stdlib.add_logger_name,
        timestamper,
    ]

    if settings.environment == "dev":
        renderer = structlog.dev.ConsoleRenderer(colors=True)
    else:
        renderer = structlog.processors.JSONRenderer()

    structlog.configure(
        processors=[
            *shared_processors,
            structlog.stdlib.ProcessorFormatter.wrap_for_formatter,
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

    formatter = structlog.stdlib.ProcessorFormatter(
        foreign_pre_chain=shared_processors,
        processor=renderer,
    )
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(formatter)

    root_logger = logging.getLogger()
    root_logger.handlers.clear()
    root_logger.addHandler(handler)
    root_logger.setLevel(logging.INFO)

    bridge_uvicorn_logging()


def bridge_uvicorn_logging() -> None:
    for name in ("uvicorn", "uvicorn.access", "uvicorn.error"):
        uv_logger = logging.getLogger(name)
        uv_logger.handlers.clear()
        uv_logger.propagate = True


class RequestIdMiddleware:
    """Binds request_id into the structlog context and emits one structured
    `request.completed` line per request (method, path, status, duration).

    Deliberately a pure ASGI middleware, not BaseHTTPMiddleware: the
    downstream app is awaited in the *same* task, so contextvars bound deeper
    in the request — `get_current_user` binds user_id — are still visible
    when the completion event is emitted. BaseHTTPMiddleware runs downstream
    in a child task whose context writes never propagate back.

    The query string is intentionally not logged (it can carry user input);
    the path plus the domain events cover tracing needs.
    """

    def __init__(self, app) -> None:
        self.app = app

    async def __call__(self, scope, receive, send) -> None:
        if scope["type"] != "http":
            await self.app(scope, receive, send)
            return

        request_id = Headers(scope=scope).get("x-request-id") or str(uuid.uuid4())
        structlog.contextvars.bind_contextvars(request_id=request_id)
        started = time.perf_counter()
        status_code = 500  # what the outer error middleware answers if we never send

        async def send_with_request_id(message) -> None:
            nonlocal status_code
            if message["type"] == "http.response.start":
                status_code = message["status"]
                MutableHeaders(scope=message).append("X-Request-ID", request_id)
            await send(message)

        try:
            await self.app(scope, receive, send_with_request_id)
        finally:
            # Emitted in the finally so crashes still produce a completion
            # line (status 500); merge_contextvars adds request_id + user_id.
            # get_logger here (not module level): a cached module logger bakes
            # in the processor chain from its first use, which breaks capture
            # in tests; the lazy proxy binds from the current config.
            structlog.get_logger("request").info(
                "request.completed",
                method=scope["method"],
                path=scope["path"],
                status=status_code,
                duration_ms=round((time.perf_counter() - started) * 1000, 1),
            )
            structlog.contextvars.clear_contextvars()
