from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


class WeatherProviderError(Exception):
    """Domain-level weather provider failure. Routes translate to 5xx (or domain-specific code).

    Codes: `weather_auth_failed` (key/membership rejected — never self-heals),
    `weather_quota_exceeded`, `weather_upstream_error` (provider 5xx),
    `weather_call_failed` (network/timeout), `weather_bad_payload`.
    """

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# Transient failures worth one immediate retry; auth/quota/payload errors won't
# fix themselves within a request.
RETRYABLE_CODES = frozenset({"weather_upstream_error", "weather_call_failed"})


@dataclass(frozen=True)
class WeatherSnapshot:
    temp_c: float
    feels_like_c: float
    condition: str
    humidity_pct: int | None
    wind_kph: float | None


@dataclass(frozen=True)
class WeatherAttribution:
    """What the client must show wherever this provider's data appears."""

    service_name: str
    logo_light_url: str
    logo_dark_url: str
    legal_url: str


class WeatherProvider(ABC):
    @abstractmethod
    async def current(self, lat: float, lon: float) -> WeatherSnapshot:
        """Current conditions at lat/lon."""

    @property
    def attribution(self) -> WeatherAttribution | None:
        """Required on-screen attribution, or None when the source needs none."""
        return None
