from __future__ import annotations

import httpx
import structlog

from app.services.providers.weather.base import (
    WeatherProvider,
    WeatherProviderError,
    WeatherSnapshot,
)

_log = structlog.get_logger("provider.weather.open_meteo")
_BASE_URL = "https://api.open-meteo.com/v1/forecast"
_TIMEOUT_S = 10.0


def _condition_for_code(code: int) -> str:
    if code == 0:
        return "clear"
    if code in (1, 2, 3):
        return "cloudy"
    if code in (45, 48):
        return "fog"
    if 51 <= code <= 67 or 80 <= code <= 82:
        return "rain"
    if 71 <= code <= 77 or 85 <= code <= 86:
        return "snow"
    if 95 <= code <= 99:
        return "thunderstorm"
    return "unknown"


class OpenMeteoProvider(WeatherProvider):
    async def current(self, lat: float, lon: float) -> WeatherSnapshot:
        params = {
            "latitude": lat,
            "longitude": lon,
            "current": (
                "temperature_2m,apparent_temperature,relative_humidity_2m,"
                "wind_speed_10m,weather_code"
            ),
            "wind_speed_unit": "kmh",
            "temperature_unit": "celsius",
        }
        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_S) as client:
                resp = await client.get(_BASE_URL, params=params)
                resp.raise_for_status()
                payload = resp.json()
        except (httpx.HTTPError, ValueError) as exc:
            _log.warning("weather.current.failed", lat=lat, lon=lon, error=str(exc))
            raise WeatherProviderError(
                "weather_call_failed", f"Open-Meteo lookup failed: {exc}"
            ) from exc

        current = payload.get("current") or {}
        try:
            return WeatherSnapshot(
                temp_c=float(current["temperature_2m"]),
                feels_like_c=float(current["apparent_temperature"]),
                condition=_condition_for_code(int(current["weather_code"])),
                humidity_pct=(
                    int(current["relative_humidity_2m"])
                    if current.get("relative_humidity_2m") is not None
                    else None
                ),
                wind_kph=(
                    float(current["wind_speed_10m"])
                    if current.get("wind_speed_10m") is not None
                    else None
                ),
            )
        except (KeyError, TypeError, ValueError) as exc:
            raise WeatherProviderError(
                "weather_bad_payload", f"Unexpected Open-Meteo payload: {exc}"
            ) from exc
