"""The Gemini garment image provider's REST layer, against httpx.MockTransport."""

from __future__ import annotations

import base64
import json

import httpx
import pytest

from app.services.providers.garment_image.base import GarmentImageError
from app.services.providers.garment_image.gemini import GeminiGarmentImageProvider

_PHOTO = b"photo-bytes"
_SHOT = b"generated-bytes"


def _image_reply() -> dict:
    return {
        "candidates": [
            {
                "content": {
                    "parts": [
                        {"text": "Here you go."},
                        {
                            "inlineData": {
                                "mimeType": "image/png",
                                "data": base64.b64encode(_SHOT).decode(),
                            }
                        },
                    ]
                }
            }
        ]
    }


class _Google:
    def __init__(self, status: int = 200, body: object | None = None) -> None:
        self.status = status
        self.body = _image_reply() if body is None else body
        self.requests: list[httpx.Request] = []

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        return httpx.Response(self.status, json=self.body)


@pytest.fixture
def google(monkeypatch) -> _Google:
    handler = _Google()
    real_client = httpx.AsyncClient
    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        httpx, "AsyncClient", lambda **kwargs: real_client(transport=transport)
    )
    return handler


def _provider(endpoint: str = "gemini_api") -> GeminiGarmentImageProvider:
    return GeminiGarmentImageProvider(
        "test-key", model="gemini-3.1-flash-lite-image", endpoint=endpoint
    )


async def test_sends_the_photo_and_prompt_and_returns_the_image(google):
    image = await _provider().generate(
        _PHOTO, media_type="image/jpeg", prompt="On a mannequin"
    )

    assert image.content == _SHOT
    assert image.content_type == "image/png"
    req = google.requests[0]
    assert req.url.path == "/v1beta/models/gemini-3.1-flash-lite-image:generateContent"
    # The key travels in a header, never in the URL.
    assert req.headers["x-goog-api-key"] == "test-key"
    assert "test-key" not in str(req.url)
    content = json.loads(req.content)["contents"][0]
    assert content["role"] == "user"
    parts = content["parts"]
    assert parts[0] == {"text": "On a mannequin"}
    assert parts[1]["inline_data"] == {
        "mime_type": "image/jpeg",
        "data": base64.b64encode(_PHOTO).decode(),
    }


async def test_an_agent_platform_key_calls_agent_platform(google):
    await _provider("agent_platform").generate(
        _PHOTO, media_type="image/jpeg", prompt="p"
    )

    req = google.requests[0]
    assert req.url.host == "aiplatform.googleapis.com"
    assert req.url.path == (
        "/v1/publishers/google/models/gemini-3.1-flash-lite-image:generateContent"
    )
    assert req.headers["x-goog-api-key"] == "test-key"


async def test_an_error_status_raises(google):
    google.status = 403
    google.body = {"error": {"message": "API key not valid"}}

    with pytest.raises(GarmentImageError) as e:
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert e.value.code == "call_failed"
    assert "403" in str(e.value)


async def test_a_reply_without_an_image_raises(google):
    google.body = {"candidates": [{"content": {"parts": [{"text": "I can't."}]}}]}

    with pytest.raises(GarmentImageError) as e:
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert e.value.code == "no_image"


async def test_a_network_failure_raises(monkeypatch):
    def boom(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("down", request=request)

    real_client = httpx.AsyncClient
    monkeypatch.setattr(
        httpx,
        "AsyncClient",
        lambda **kwargs: real_client(transport=httpx.MockTransport(boom)),
    )
    with pytest.raises(GarmentImageError) as e:
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert e.value.code == "call_failed"


class _BusyThenOk(_Google):
    """429 for the first [busy] calls, then an image."""

    def __init__(self, busy: int, retry_after: str | None = None) -> None:
        super().__init__()
        self.busy = busy
        self.retry_after = retry_after

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        if len(self.requests) <= self.busy:
            headers = {"retry-after": self.retry_after} if self.retry_after else {}
            return httpx.Response(429, json={"error": {"code": 429}}, headers=headers)
        return httpx.Response(200, json=self.body)


def _patched(monkeypatch, handler) -> tuple[GeminiGarmentImageProvider, list[float]]:
    real_client = httpx.AsyncClient
    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        httpx, "AsyncClient", lambda **kwargs: real_client(transport=transport)
    )
    provider = _provider()
    slept: list[float] = []

    async def sleep(seconds: float) -> None:
        slept.append(seconds)

    provider._sleep = sleep  # type: ignore[method-assign]
    return provider, slept


async def test_a_rate_limit_is_waited_out(monkeypatch):
    handler = _BusyThenOk(busy=2)
    provider, slept = _patched(monkeypatch, handler)

    image = await provider.generate(_PHOTO, media_type="image/jpeg", prompt="p")

    assert image.content == _SHOT
    assert len(handler.requests) == 3
    assert slept == list(provider.retry_waits[:2])  # growing waits


async def test_googles_retry_after_is_honoured_up_to_the_cap(monkeypatch):
    handler = _BusyThenOk(busy=2, retry_after="7")
    provider, slept = _patched(monkeypatch, handler)
    provider.retry_waits = (5.0, 6.0)

    await provider.generate(_PHOTO, media_type="image/jpeg", prompt="p")

    assert slept == [6.0, 6.0]  # 7 s asked, capped at the longest wait


async def test_a_rate_limit_that_lasts_gives_up(monkeypatch):
    handler = _BusyThenOk(busy=99)
    provider, slept = _patched(monkeypatch, handler)

    with pytest.raises(GarmentImageError) as e:
        await provider.generate(_PHOTO, media_type="image/jpeg", prompt="p")

    assert e.value.code == "call_failed" and "429" in str(e.value)
    assert len(handler.requests) == len(provider.retry_waits) + 1
