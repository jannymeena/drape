"""Per-IP sliding-window rate limiting for the auth endpoints (§3.1 hardening).

In-process on purpose: tbd/prd run a single uvicorn worker per box, so a
shared store (redis) buys nothing yet. If prd ever scales past one process,
swap the limiter for a shared backend behind the same dependency.

Wiring: `dependencies=[Depends(rate_limited("login"))]` on a route. The limit
comes from `settings.auth_rate_limit_per_minute` at request time (0 = off —
the dev/test default; tbd/prd force a floor in Settings._validate).
"""
from __future__ import annotations

import threading
import time
from collections import defaultdict, deque

import structlog
from fastapi import HTTPException, Request, status

from app.core.config import settings

_log = structlog.get_logger("rate_limit")

_WINDOW_SECONDS = 60.0

# Entries are (deque of hit timestamps) per "<scope>:<ip>" key. Old keys are
# pruned opportunistically on each hit so the map can't grow unbounded.
_PRUNE_EVERY = 512


class SlidingWindowLimiter:
    def __init__(self, window_seconds: float = _WINDOW_SECONDS) -> None:
        self._window = window_seconds
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()
        self._ops = 0

    def allow(self, key: str, *, limit: int, now: float | None = None) -> bool:
        """Record a hit for `key` and return whether it is within `limit`
        hits per window. Denied hits are also recorded — hammering while
        throttled does not earn earlier release."""
        ts = time.monotonic() if now is None else now
        cutoff = ts - self._window
        with self._lock:
            self._ops += 1
            if self._ops % _PRUNE_EVERY == 0:
                self._prune(cutoff)
            hits = self._hits[key]
            while hits and hits[0] <= cutoff:
                hits.popleft()
            hits.append(ts)
            return len(hits) <= limit

    def _prune(self, cutoff: float) -> None:
        dead = [k for k, v in self._hits.items() if not v or v[-1] <= cutoff]
        for k in dead:
            del self._hits[k]

    def reset(self) -> None:
        """Test hook — drop all recorded hits."""
        with self._lock:
            self._hits.clear()


_limiter = SlidingWindowLimiter()


def _client_ip(request: Request) -> str:
    """Real client IP. Behind Caddy (tbd/prd) uvicorn sees 127.0.0.1 and the
    client is the first X-Forwarded-For hop; Caddy always overwrites the
    header, so it is trustworthy there. Direct connections (dev) have no XFF.
    """
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else "unknown"


def rate_limited(scope: str):
    """Dependency factory: throttle a route per client IP under `scope`."""

    def dependency(request: Request) -> None:
        limit = settings.auth_rate_limit_per_minute
        if limit <= 0:
            return
        ip = _client_ip(request)
        if not _limiter.allow(f"{scope}:{ip}", limit=limit):
            _log.warning("rate_limit.throttled", scope=scope, ip=ip)
            raise HTTPException(
                status_code=status.HTTP_429_TOO_MANY_REQUESTS,
                detail={
                    "code": "rate_limited",
                    "message": "Too many attempts. Please wait a minute and try again.",
                },
            )

    return dependency
