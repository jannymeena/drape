"""WeatherKit provider (JWT auth, payload mapping, error codes) and the shared
~1 km weather cache (fresh/stale windows, retry, backoff, loud failure log).

WeatherKit's httpx layer runs against httpx.MockTransport; the cache is tested
against an in-memory fake provider with a controllable clock.
"""
from __future__ import annotations

import asyncio
import base64

import httpx
import jwt
import pytest
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from structlog.testing import capture_logs

from app.core.config import Settings
from app.services.providers.weather.base import (
    WeatherProvider,
    WeatherProviderError,
    WeatherSnapshot,
)
from app.services.providers.weather.caching import CachingWeatherProvider, area_key
from app.services.providers.weather.weatherkit import WeatherKitProvider

# ---------------------------------------------------------------------------
# WeatherKitProvider
# ---------------------------------------------------------------------------

_KEY = ec.generate_private_key(ec.SECP256R1())
_PEM = _KEY.private_bytes(
    serialization.Encoding.PEM,
    serialization.PrivateFormat.PKCS8,
    serialization.NoEncryption(),
).decode()

_PAYLOAD = {
    "currentWeather": {
        "temperature": 20.63,
        "temperatureApparent": 19.04,
        "conditionCode": "MostlyCloudy",
        "humidity": 0.79,
        "windSpeed": 12.45,
    }
}


class _Apple:
    """MockTransport handler recording requests; replies with a fixed response."""

    def __init__(self, status: int = 200, body: object = _PAYLOAD) -> None:
        self.status = status
        self.body = body
        self.requests: list[httpx.Request] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        return httpx.Response(self.status, json=self.body)


@pytest.fixture
def apple(monkeypatch) -> _Apple:
    handler = _Apple()
    real_client = httpx.AsyncClient
    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        httpx, "AsyncClient", lambda **kwargs: real_client(transport=transport)
    )
    return handler


def _weatherkit(private_key: str = _PEM) -> WeatherKitProvider:
    return WeatherKitProvider(
        team_id="TEAM123456",
        service_id="style.zoura.weatherkit",
        key_id="KEY1234567",
        private_key=private_key,
    )


async def test_weatherkit_maps_current_weather(apple):
    snap = await _weatherkit().current(43.65, -79.38)

    assert snap == WeatherSnapshot(
        temp_c=20.63, feels_like_c=19.04, condition="cloudy", humidity_pct=79, wind_kph=12.45
    )
    req = apple.requests[0]
    assert req.url.path == "/api/v1/weather/en/43.6500/-79.3800"
    assert req.url.params["dataSets"] == "currentWeather"


async def test_weatherkit_signs_an_es256_jwt(apple):
    await _weatherkit().current(43.65, -79.38)

    token = apple.requests[0].headers["Authorization"].removeprefix("Bearer ")
    header = jwt.get_unverified_header(token)
    assert header["alg"] == "ES256"
    assert header["kid"] == "KEY1234567"
    assert header["id"] == "TEAM123456.style.zoura.weatherkit"
    claims = jwt.decode(token, _KEY.public_key(), algorithms=["ES256"])
    assert claims["iss"] == "TEAM123456"
    assert claims["sub"] == "style.zoura.weatherkit"
    assert claims["exp"] > claims["iat"]


async def test_weatherkit_reuses_its_token(apple):
    provider = _weatherkit()
    await provider.current(43.65, -79.38)
    await provider.current(45.50, -73.57)

    auth = {r.headers["Authorization"] for r in apple.requests}
    assert len(auth) == 1


def test_weatherkit_accepts_base64_key():
    _weatherkit(base64.b64encode(_PEM.encode()).decode())


def test_weatherkit_rejects_a_bad_key_at_construction():
    with pytest.raises(ValueError, match="WEATHERKIT_PRIVATE_KEY"):
        _weatherkit("not-a-key")


@pytest.mark.parametrize(
    ("code", "expected"),
    [
        ("Clear", "clear"),
        ("PartlyCloudy", "cloudy"),
        ("Haze", "fog"),
        ("Drizzle", "rain"),
        ("WintryMix", "snow"),
        ("StrongStorms", "thunderstorm"),
        ("Windy", "windy"),
        ("SomethingNew", "unknown"),
    ],
)
async def test_weatherkit_condition_mapping(apple, code, expected):
    apple.body = {"currentWeather": {**_PAYLOAD["currentWeather"], "conditionCode": code}}
    assert (await _weatherkit().current(0, 0)).condition == expected


@pytest.mark.parametrize(
    ("status", "error_code"),
    [
        (401, "weather_auth_failed"),
        (403, "weather_auth_failed"),
        (429, "weather_quota_exceeded"),
        (503, "weather_upstream_error"),
    ],
)
async def test_weatherkit_http_errors_are_typed(apple, status, error_code):
    apple.status = status
    with pytest.raises(WeatherProviderError) as exc:
        await _weatherkit().current(43.65, -79.38)
    assert exc.value.code == error_code


async def test_weatherkit_bad_payload(apple):
    apple.body = {"currentWeather": {"temperature": 20}}
    with pytest.raises(WeatherProviderError) as exc:
        await _weatherkit().current(43.65, -79.38)
    assert exc.value.code == "weather_bad_payload"


def test_weatherkit_attribution():
    attribution = _weatherkit().attribution
    assert attribution.service_name == "Apple Weather"
    assert attribution.legal_url == "https://weatherkit.apple.com/legal-attribution.html"


# ---------------------------------------------------------------------------
# CachingWeatherProvider
# ---------------------------------------------------------------------------

_SNAP = WeatherSnapshot(
    temp_c=10.0, feels_like_c=8.0, condition="clear", humidity_pct=50, wind_kph=5.0
)


class _Fake(WeatherProvider):
    def __init__(self) -> None:
        self.calls: list[tuple[float, float]] = []
        self.failures: list[str] = []  # error codes to raise, consumed in order

    async def current(self, lat: float, lon: float) -> WeatherSnapshot:
        self.calls.append((lat, lon))
        await asyncio.sleep(0)
        if self.failures:
            raise WeatherProviderError(self.failures.pop(0), "boom")
        return _SNAP


class _Clock:
    def __init__(self) -> None:
        self.now = 1000.0

    def __call__(self) -> float:
        return self.now


@pytest.fixture
def fake() -> _Fake:
    return _Fake()


@pytest.fixture
def clock() -> _Clock:
    return _Clock()


@pytest.fixture
def cache(fake, clock) -> CachingWeatherProvider:
    return CachingWeatherProvider(fake, clock=clock)


def test_area_key_rounds_to_about_a_kilometre():
    assert area_key(43.65321, -79.38349) == (43.65, -79.38)
    assert area_key(-0.001, 0.0) == (0.0, 0.0)


async def test_nearby_coords_share_one_upstream_call(cache, fake):
    await cache.current(43.6532, -79.3832)
    await cache.current(43.6511, -79.3801)  # same ~1 km cell

    assert fake.calls == [(43.65, -79.38)]  # and only rounded coords go upstream


async def test_different_areas_are_cached_separately(cache, fake):
    await cache.current(43.65, -79.38)
    await cache.current(43.70, -79.40)
    assert len(fake.calls) == 2


async def test_refetches_after_the_fresh_window(cache, fake, clock):
    await cache.current(43.65, -79.38)
    clock.now += 14 * 60
    await cache.current(43.65, -79.38)
    assert len(fake.calls) == 1

    clock.now += 2 * 60
    await cache.current(43.65, -79.38)
    assert len(fake.calls) == 2


async def test_concurrent_requests_for_one_area_make_one_call(cache, fake):
    await asyncio.gather(*(cache.current(43.65, -79.38) for _ in range(5)))
    assert len(fake.calls) == 1


async def test_transient_error_is_retried_once(cache, fake):
    fake.failures = ["weather_upstream_error"]
    assert await cache.current(43.65, -79.38) == _SNAP
    assert len(fake.calls) == 2


async def test_auth_failure_is_not_retried_and_logged_loudly(cache, fake):
    fake.failures = ["weather_auth_failed"]
    with capture_logs() as logs, pytest.raises(WeatherProviderError):
        await cache.current(43.6532, -79.3832)

    assert len(fake.calls) == 1
    [event] = [e for e in logs if e["event"] == "weather.provider_down"]
    assert event["log_level"] == "error"
    assert event["code"] == "weather_auth_failed"
    assert event["provider"] == "_Fake"
    assert event["area"] == "43.65,-79.38"  # never the exact coords
    assert event["served_stale"] is False


async def test_failure_serves_stale_value_and_still_logs(cache, fake, clock):
    await cache.current(43.65, -79.38)
    clock.now += 60 * 60
    fake.failures = ["weather_quota_exceeded"]

    with capture_logs() as logs:
        assert await cache.current(43.65, -79.38) == _SNAP

    [event] = [e for e in logs if e["event"] == "weather.provider_down"]
    assert event["served_stale"] is True
    assert event["stale_age_min"] == 60


async def test_stale_value_expires_after_six_hours(cache, fake, clock):
    await cache.current(43.65, -79.38)
    clock.now += 7 * 3600
    fake.failures = ["weather_auth_failed"]
    with pytest.raises(WeatherProviderError):
        await cache.current(43.65, -79.38)


async def test_backs_off_after_a_failure(cache, fake, clock):
    fake.failures = ["weather_auth_failed"]
    with pytest.raises(WeatherProviderError):
        await cache.current(43.65, -79.38)

    with capture_logs() as logs, pytest.raises(WeatherProviderError) as exc:
        await cache.current(43.65, -79.38)
    assert exc.value.code == "weather_auth_failed"
    assert len(fake.calls) == 1  # no upstream call during backoff
    assert not [e for e in logs if e["event"] == "weather.provider_down"]

    clock.now += 61
    assert await cache.current(43.65, -79.38) == _SNAP
    assert len(fake.calls) == 2


def test_cache_passes_attribution_through():
    inner = _weatherkit()
    assert CachingWeatherProvider(inner).attribution == inner.attribution
    assert CachingWeatherProvider(_Fake()).attribution is None


# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

_WK = {
    "weatherkit_team_id": "T",
    "weatherkit_service_id": "S",
    "weatherkit_key_id": "K",
    "weatherkit_private_key": _PEM,
}


def test_partial_weatherkit_config_fails_at_startup():
    with pytest.raises(ValueError, match="WEATHERKIT_KEY_ID"):
        Settings(
            _env_file=None,
            measurement_dek_dev="x",
            weatherkit_team_id="T",
            weatherkit_service_id="S",
        )


def test_weatherkit_configured_needs_all_four_keys():
    assert Settings(_env_file=None, measurement_dek_dev="x", **_WK).weatherkit_configured
    assert not Settings(_env_file=None, measurement_dek_dev="x").weatherkit_configured
