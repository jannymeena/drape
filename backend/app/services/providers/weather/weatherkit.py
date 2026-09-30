"""Apple WeatherKit REST provider (tbd/prd; dev when the four WEATHERKIT_* keys are set).

Auth is a short-lived ES256 JWT we sign ourselves with the WeatherKit .p8 key
(Apple Developer → Keys). The token is reused until shortly before it expires.

Apple's terms require the Apple Weather mark + a link to the data-sources page
wherever the data is shown — exposed via `attribution` for the client.
"""
from __future__ import annotations

import base64
import time

import httpx
import jwt
from cryptography.hazmat.primitives.serialization import load_pem_private_key

from app.services.providers.weather.base import (
    WeatherAttribution,
    WeatherProvider,
    WeatherProviderError,
    WeatherSnapshot,
)

_BASE_URL = "https://weatherkit.apple.com/api/v1/weather/en"
_TIMEOUT_S = 10.0
_TOKEN_TTL_S = 3600
_TOKEN_REFRESH_MARGIN_S = 300

# Logo paths as served by https://weatherkit.apple.com/attribution/en.
_ATTRIBUTION = WeatherAttribution(
    service_name="Apple Weather",
    logo_light_url="https://weatherkit.apple.com/assets/branding/en/Apple_Weather_blk_en_3X_090122.png",
    logo_dark_url="https://weatherkit.apple.com/assets/branding/en/Apple_Weather_wht_en_3X_090122.png",
    legal_url="https://weatherkit.apple.com/legal-attribution.html",
)

# WeatherKit `conditionCode` → our small condition vocabulary (shared with
# Open-Meteo, plus "windy", which Open-Meteo's WMO codes can't express).
_CONDITIONS = {
    "clear": {"Clear", "MostlyClear", "Hot", "Frigid"},
    "cloudy": {"PartlyCloudy", "MostlyCloudy", "Cloudy"},
    "fog": {"Foggy", "Haze", "Smoky", "BlowingDust"},
    "rain": {
        "Drizzle", "Rain", "HeavyRain", "SunShowers", "FreezingDrizzle",
        "FreezingRain", "Hail",
    },
    "snow": {
        "Flurries", "SunFlurries", "Snow", "HeavySnow", "Sleet", "WintryMix",
        "Blizzard", "BlowingSnow",
    },
    "thunderstorm": {
        "IsolatedThunderstorms", "ScatteredThunderstorms", "StrongStorms",
        "Thunderstorms", "Hurricane", "TropicalStorm",
    },
    "windy": {"Breezy", "Windy"},
}
_CONDITION_BY_CODE = {code: cond for cond, codes in _CONDITIONS.items() for code in codes}


def _load_private_key(raw: str):
    """Accept the .p8 PEM verbatim or base64-encoded — the .env envelope is
    line-based, so base64 is the transport-safe form (same as FCM)."""
    pem = raw.strip()
    if "BEGIN PRIVATE KEY" not in pem:
        try:
            pem = base64.b64decode(pem, validate=True).decode()
        except ValueError as exc:
            raise ValueError(
                "WEATHERKIT_PRIVATE_KEY is neither a PEM nor base64-encoded PEM"
            ) from exc
    try:
        return load_pem_private_key(pem.encode(), password=None)
    except ValueError as exc:
        raise ValueError("WEATHERKIT_PRIVATE_KEY is not a valid .p8 private key") from exc


class WeatherKitProvider(WeatherProvider):
    def __init__(self, *, team_id: str, service_id: str, key_id: str, private_key: str) -> None:
        self._team_id = team_id
        self._service_id = service_id
        self._key_id = key_id
        # Parsed at construction so a bad key fails at startup, not per request.
        self._private_key = _load_private_key(private_key)
        self._token: str | None = None
        self._token_expires_at = 0.0

    @property
    def attribution(self) -> WeatherAttribution:
        return _ATTRIBUTION

    def _bearer_token(self) -> str:
        now = time.time()
        if self._token is None or now >= self._token_expires_at - _TOKEN_REFRESH_MARGIN_S:
            issued = int(now)
            self._token = jwt.encode(
                {
                    "iss": self._team_id,
                    "sub": self._service_id,
                    "iat": issued,
                    "exp": issued + _TOKEN_TTL_S,
                },
                self._private_key,
                algorithm="ES256",
                headers={"kid": self._key_id, "id": f"{self._team_id}.{self._service_id}"},
            )
            self._token_expires_at = issued + _TOKEN_TTL_S
        return self._token

    async def current(self, lat: float, lon: float) -> WeatherSnapshot:
        url = f"{_BASE_URL}/{lat:.4f}/{lon:.4f}"
        headers = {"Authorization": f"Bearer {self._bearer_token()}"}
        try:
            async with httpx.AsyncClient(timeout=_TIMEOUT_S) as client:
                resp = await client.get(
                    url, params={"dataSets": "currentWeather"}, headers=headers
                )
        except httpx.HTTPError as exc:
            raise WeatherProviderError(
                "weather_call_failed", f"WeatherKit lookup failed: {exc!r}"
            ) from exc

        if resp.status_code in (401, 403):
            # Forget the token so the next call re-signs (covers a rotated key).
            self._token = None
            raise WeatherProviderError(
                "weather_auth_failed",
                f"WeatherKit rejected our credentials (HTTP {resp.status_code}) — "
                "check the key, Services ID, and Apple Developer membership",
            )
        if resp.status_code == 429:
            raise WeatherProviderError("weather_quota_exceeded", "WeatherKit quota exceeded")
        if resp.status_code >= 400:
            raise WeatherProviderError(
                "weather_upstream_error", f"WeatherKit returned HTTP {resp.status_code}"
            )

        try:
            current = resp.json()["currentWeather"]
            humidity = current.get("humidity")
            wind = current.get("windSpeed")
            return WeatherSnapshot(
                temp_c=float(current["temperature"]),
                feels_like_c=float(current["temperatureApparent"]),
                condition=_CONDITION_BY_CODE.get(current.get("conditionCode"), "unknown"),
                humidity_pct=round(float(humidity) * 100) if humidity is not None else None,
                wind_kph=float(wind) if wind is not None else None,
            )
        except (KeyError, TypeError, ValueError) as exc:
            raise WeatherProviderError(
                "weather_bad_payload", f"Unexpected WeatherKit payload: {exc!r}"
            ) from exc
