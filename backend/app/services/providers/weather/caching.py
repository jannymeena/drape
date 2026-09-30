"""Shared, in-process weather cache keyed by ~1 km area.

`CachingWeatherProvider` decorates the real provider (every env):

* **Area key.** Coords are rounded to 2 decimals (~1.1 km N-S) — about the grid
  size of the underlying weather models, so nothing is lost — and only the
  rounded coords are sent upstream: the provider never sees an exact location.
* **Shared.** Keyed by area, not user: the first user in an area pays the call,
  everyone nearby within the fresh window is served from memory.
* **Fresh / stale.** Entries are fresh for 15 min. When the provider fails, the
  last value (up to 6 h old) is served instead of nothing.
* **Loud failures.** Every provider failure is logged once at ERROR as
  `weather.provider_down` (code, provider, area, whether stale was served) —
  this is the event to watch / alarm on. Transient errors get one retry first.
  After a failure the area backs off for a minute so an outage doesn't turn
  every request into two upstream calls + an error line.

In-process on purpose: a restart only costs one call per active area. Revisit
(e.g. a Postgres table) if we run many instances.
"""
from __future__ import annotations

import asyncio
import time
from collections.abc import Callable
from dataclasses import dataclass

import structlog

from app.services.providers.weather.base import (
    RETRYABLE_CODES,
    WeatherAttribution,
    WeatherProvider,
    WeatherProviderError,
    WeatherSnapshot,
)

_log = structlog.get_logger("provider.weather.caching")

FRESH_TTL_S = 15 * 60
STALE_TTL_S = 6 * 3600
FAILURE_BACKOFF_S = 60
_PRUNE_ABOVE = 5000


def area_key(lat: float, lon: float) -> tuple[float, float]:
    # `+ 0.0` normalizes -0.0 so it shares a key with 0.0.
    return round(lat, 2) + 0.0, round(lon, 2) + 0.0


@dataclass
class _Entry:
    snapshot: WeatherSnapshot | None = None
    fetched_at: float = 0.0
    failed_at: float | None = None
    failure_code: str | None = None


class CachingWeatherProvider(WeatherProvider):
    def __init__(
        self,
        inner: WeatherProvider,
        *,
        fresh_ttl_s: float = FRESH_TTL_S,
        stale_ttl_s: float = STALE_TTL_S,
        failure_backoff_s: float = FAILURE_BACKOFF_S,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._inner = inner
        self._fresh_ttl_s = fresh_ttl_s
        self._stale_ttl_s = stale_ttl_s
        self._failure_backoff_s = failure_backoff_s
        self._clock = clock
        self._entries: dict[tuple[float, float], _Entry] = {}
        self._locks: dict[tuple[float, float], asyncio.Lock] = {}

    @property
    def inner(self) -> WeatherProvider:
        return self._inner

    @property
    def attribution(self) -> WeatherAttribution | None:
        return self._inner.attribution

    def _fresh(self, entry: _Entry | None, now: float) -> WeatherSnapshot | None:
        if entry and entry.snapshot and now - entry.fetched_at < self._fresh_ttl_s:
            return entry.snapshot
        return None

    def _stale(self, entry: _Entry | None, now: float) -> WeatherSnapshot | None:
        if entry and entry.snapshot and now - entry.fetched_at < self._stale_ttl_s:
            return entry.snapshot
        return None

    async def current(self, lat: float, lon: float) -> WeatherSnapshot:
        key = area_key(lat, lon)
        if snap := self._fresh(self._entries.get(key), self._clock()):
            return snap

        # One upstream call per area at a time; waiters re-check the cache.
        lock = self._locks.setdefault(key, asyncio.Lock())
        async with lock:
            now = self._clock()
            entry = self._entries.setdefault(key, _Entry())
            if snap := self._fresh(entry, now):
                return snap

            if entry.failed_at is not None and now - entry.failed_at < self._failure_backoff_s:
                if snap := self._stale(entry, now):
                    return snap
                raise WeatherProviderError(
                    entry.failure_code or "weather_call_failed",
                    "Weather provider failed moments ago; backing off",
                )

            try:
                snap = await self._fetch(*key)
            except WeatherProviderError as exc:
                entry.failed_at, entry.failure_code = now, exc.code
                stale = self._stale(entry, now)
                _log.error(
                    "weather.provider_down",
                    provider=type(self._inner).__name__,
                    code=exc.code,
                    error=str(exc),
                    area=f"{key[0]:.2f},{key[1]:.2f}",
                    served_stale=stale is not None,
                    stale_age_min=(
                        round((now - entry.fetched_at) / 60) if stale is not None else None
                    ),
                )
                if stale is not None:
                    return stale
                raise

            entry.snapshot, entry.fetched_at = snap, now
            entry.failed_at = entry.failure_code = None
            self._prune(now)
            return snap

    async def _fetch(self, lat: float, lon: float) -> WeatherSnapshot:
        try:
            return await self._inner.current(lat, lon)
        except WeatherProviderError as exc:
            if exc.code not in RETRYABLE_CODES:
                raise
            _log.warning("weather.retrying", provider=type(self._inner).__name__, code=exc.code)
            return await self._inner.current(lat, lon)

    def _prune(self, now: float) -> None:
        if len(self._entries) <= _PRUNE_ABOVE:
            return
        for key, entry in list(self._entries.items()):
            lock = self._locks.get(key)
            if now - entry.fetched_at >= self._stale_ttl_s and not (lock and lock.locked()):
                del self._entries[key]
                self._locks.pop(key, None)
