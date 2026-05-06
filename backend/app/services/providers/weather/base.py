from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


class WeatherProviderError(Exception):
    """Domain-level weather provider failure. Routes translate to 5xx (or domain-specific code)."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


@dataclass(frozen=True)
class WeatherSnapshot:
    temp_c: float
    feels_like_c: float
    condition: str
    humidity_pct: int | None
    wind_kph: float | None


class WeatherProvider(ABC):
    @abstractmethod
    async def current(self, lat: float, lon: float) -> WeatherSnapshot:
        """Current conditions at lat/lon."""
