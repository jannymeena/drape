"""The Runware garment image provider's REST layer, against httpx.MockTransport."""

from __future__ import annotations

import base64
import io
import json

import httpx
import pytest
import structlog.testing
from PIL import Image

from app.services.providers.garment_image.base import GarmentImageError
from app.services.providers.garment_image.runware import (
    API_URL,
    RunwareGarmentImageProvider,
    output_size,
)

_SHOT = b"generated-bytes"
_MODEL = "openai:gpt-image@2.6-flare"


def _photo(size=(600, 800)) -> bytes:
    out = io.BytesIO()
    Image.new("RGB", size, (200, 200, 200)).save(out, format="JPEG")
    return out.getvalue()


_PHOTO = _photo()


def _task_uuid(request: httpx.Request) -> str:
    return json.loads(request.content)[0]["taskUUID"]


class _Runware:
    """Answers each call with [status] and [body]; by default an image for
    the task that was sent."""

    def __init__(self, status: int = 200, body: object | None = None) -> None:
        self.status = status
        self.body = body
        self.requests: list[httpx.Request] = []

    def image_reply(self, request: httpx.Request) -> dict:
        return {
            "data": [
                {
                    "taskType": "imageInference",
                    "taskUUID": _task_uuid(request),
                    "imageUUID": "img-1",
                    "imageBase64Data": base64.b64encode(_SHOT).decode(),
                    "cost": 0.01,
                }
            ]
        }

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        body = self.image_reply(request) if self.body is None else self.body
        return httpx.Response(self.status, json=body)


def _patch_transport(monkeypatch, handler) -> None:
    real_client = httpx.AsyncClient
    transport = httpx.MockTransport(handler)
    monkeypatch.setattr(
        httpx, "AsyncClient", lambda **kwargs: real_client(transport=transport)
    )


@pytest.fixture
def runware(monkeypatch) -> _Runware:
    handler = _Runware()
    _patch_transport(monkeypatch, handler)
    return handler


def _provider() -> RunwareGarmentImageProvider:
    return RunwareGarmentImageProvider("test-key", model=_MODEL)


async def test_sends_the_photo_and_prompt_and_returns_the_image(runware):
    image = await _provider().generate(
        _PHOTO, media_type="image/jpeg", prompt="On a mannequin"
    )

    assert image.content == _SHOT
    assert image.content_type == "image/png"
    req = runware.requests[0]
    assert str(req.url) == API_URL
    # The key travels in a header, never in the URL or the body.
    assert req.headers["authorization"] == "Bearer test-key"
    assert "test-key" not in str(req.url)
    assert b"test-key" not in req.content
    [task] = json.loads(req.content)
    assert task["taskType"] == "imageInference"
    assert task["model"] == _MODEL
    assert task["positivePrompt"] == "On a mannequin"
    assert task["inputs"]["referenceImages"] == [
        "data:image/jpeg;base64," + base64.b64encode(_PHOTO).decode()
    ]
    assert task["outputType"] == "base64Data"
    assert task["outputFormat"] == "PNG"
    assert task["numberResults"] == 1
    assert task["includeCost"] is True
    assert (task["width"], task["height"]) == output_size(_PHOTO)


async def test_the_background_is_opaque_unless_asked_for_transparent(runware):
    await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    await _provider().generate(
        _PHOTO, media_type="image/jpeg", prompt="p", transparent=True
    )

    opaque, clear = (json.loads(r.content)[0] for r in runware.requests)
    assert opaque["settings"] == {"background": "opaque"}
    assert clear["settings"] == {"background": "transparent"}
    assert clear["outputFormat"] == "PNG"


async def test_a_transparent_jpg_is_refused_before_any_call(runware):
    with pytest.raises(ValueError):
        await _provider().generate(
            _PHOTO,
            media_type="image/jpeg",
            prompt="p",
            output_format="jpg",
            transparent=True,
        )
    assert runware.requests == []


async def test_a_size_asked_for_is_used_whatever_the_photos_shape(runware):
    await _provider().generate(
        _photo((554, 554)), media_type="image/jpeg", prompt="p", size=(896, 1120)
    )

    [task] = json.loads(runware.requests[0].content)
    assert (task["width"], task["height"]) == (896, 1120)


@pytest.mark.parametrize(
    "size",
    [(900, 1120), (512, 512), (4000, 2000), (640, 2048)],
    ids=["not-16s", "too-small", "too-big", "too-tall"],
)
async def test_a_size_runware_cant_make_is_refused_before_any_call(runware, size):
    with pytest.raises(ValueError):
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p", size=size)
    assert runware.requests == []


def test_the_mannequin_size_is_one_runware_can_make():
    from app.services.image_job_service import MANNEQUIN_SIZE
    from app.services.providers.garment_image.runware import _check_size

    _check_size(*MANNEQUIN_SIZE)  # raises if not


async def test_the_cost_runware_reports_is_logged(runware):
    with structlog.testing.capture_logs() as logs:
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")

    [generated] = [e for e in logs if e["event"] == "garment_image.generated"]
    assert generated["cost_usd"] == 0.01


async def test_jpg_output_is_asked_for_and_labelled(runware):
    image = await _provider().generate(
        _PHOTO, media_type="image/jpeg", prompt="p", output_format="jpg"
    )

    assert image.content_type == "image/jpeg"
    [task] = json.loads(runware.requests[0].content)
    assert task["outputFormat"] == "JPG"


@pytest.mark.parametrize(
    "size", [(600, 800), (800, 600), (1000, 1000), (100, 5000), (4000, 300)]
)
def test_the_output_size_follows_the_photo_within_runwares_limits(size):
    width, height = output_size(_photo(size))

    assert width % 16 == 0 and height % 16 == 0
    assert 0.66e6 <= width * height <= 8.29e6
    assert 1 / 3 <= width / height <= 3
    # Same orientation as the photo.
    assert (width > height) == (size[0] > size[1]) or size[0] == size[1]


def test_an_unreadable_photo_gets_a_square():
    assert output_size(b"not an image") == (1024, 1024)


async def test_a_data_uri_reply_is_decoded(runware):
    def reply(request):
        return {
            "data": [
                {
                    "taskUUID": _task_uuid(request),
                    "imageDataURI": "data:image/png;base64,"
                    + base64.b64encode(_SHOT).decode(),
                }
            ]
        }

    runware.image_reply = reply  # type: ignore[method-assign]

    image = await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert image.content == _SHOT


async def test_a_url_reply_is_downloaded(monkeypatch):
    seen: list[httpx.Request] = []

    def handler(request: httpx.Request) -> httpx.Response:
        seen.append(request)
        if request.method == "GET":
            return httpx.Response(200, content=_SHOT)
        return httpx.Response(
            200,
            json={
                "data": [
                    {
                        "taskUUID": _task_uuid(request),
                        "imageURL": "https://im.runware.ai/image/img-1.png",
                    }
                ]
            },
        )

    _patch_transport(monkeypatch, handler)

    image = await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert image.content == _SHOT
    assert seen[1].url.host == "im.runware.ai"


async def test_an_error_status_raises_with_runwares_message(runware):
    runware.status = 401
    runware.body = {"errors": [{"code": "invalidApiKey", "message": "Invalid API key"}]}

    with pytest.raises(GarmentImageError) as e:
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert e.value.code == "call_failed"
    assert "401" in str(e.value) and "Invalid API key" in str(e.value)


async def test_errors_in_a_200_reply_raise(runware):
    runware.body = {"errors": [{"code": "invalidParameter", "message": "bad width"}]}

    with pytest.raises(GarmentImageError) as e:
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert e.value.code == "call_failed" and "bad width" in str(e.value)


async def test_a_reply_without_an_image_raises(runware):
    runware.body = {"data": [{"taskType": "imageInference", "taskUUID": "x"}]}

    with pytest.raises(GarmentImageError) as e:
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert e.value.code == "no_image"


async def test_a_task_still_processing_raises(runware):
    runware.body = {"data": [{"taskUUID": "x", "status": "processing"}]}

    with pytest.raises(GarmentImageError) as e:
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert e.value.code == "call_failed" and "processing" in str(e.value)


async def test_a_network_failure_raises(monkeypatch):
    def boom(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("down", request=request)

    _patch_transport(monkeypatch, boom)
    with pytest.raises(GarmentImageError) as e:
        await _provider().generate(_PHOTO, media_type="image/jpeg", prompt="p")
    assert e.value.code == "call_failed"


class _BusyThenOk(_Runware):
    """[status] (429 by default) for the first [busy] calls, then an image."""

    def __init__(
        self,
        busy: int,
        *,
        status: int = 429,
        retry_after: str | None = None,
        body_retry_after: float | None = None,
    ) -> None:
        super().__init__()
        self.busy = busy
        self.busy_status = status
        self.retry_after = retry_after
        self.body_retry_after = body_retry_after

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        if len(self.requests) <= self.busy:
            headers = {"retry-after": self.retry_after} if self.retry_after else {}
            error: dict = {"code": "inferenceRateLimitExceeded", "message": "busy"}
            if self.body_retry_after is not None:
                error["retryAfter"] = self.body_retry_after
            return httpx.Response(
                self.busy_status, json={"errors": [error]}, headers=headers
            )
        return httpx.Response(200, json=self.image_reply(request))


def _patched(monkeypatch, handler) -> tuple[RunwareGarmentImageProvider, list[float]]:
    _patch_transport(monkeypatch, handler)
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


async def test_a_503_is_retried_too(monkeypatch):
    handler = _BusyThenOk(busy=1, status=503)
    provider, slept = _patched(monkeypatch, handler)

    image = await provider.generate(_PHOTO, media_type="image/jpeg", prompt="p")

    assert image.content == _SHOT
    assert len(slept) == 1


async def test_retry_after_is_honoured_up_to_the_cap(monkeypatch):
    handler = _BusyThenOk(busy=2, retry_after="7")
    provider, slept = _patched(monkeypatch, handler)
    provider.retry_waits = (5.0, 6.0)

    await provider.generate(_PHOTO, media_type="image/jpeg", prompt="p")

    assert slept == [6.0, 6.0]  # 7 s asked, capped at the longest wait


async def test_retry_after_in_the_error_body_is_honoured(monkeypatch):
    handler = _BusyThenOk(busy=1, body_retry_after=2)
    provider, slept = _patched(monkeypatch, handler)

    await provider.generate(_PHOTO, media_type="image/jpeg", prompt="p")

    assert slept == [2.0]


async def test_a_rate_limit_that_lasts_gives_up(monkeypatch):
    handler = _BusyThenOk(busy=99)
    provider, slept = _patched(monkeypatch, handler)

    with pytest.raises(GarmentImageError) as e:
        await provider.generate(_PHOTO, media_type="image/jpeg", prompt="p")

    assert e.value.code == "call_failed" and "429" in str(e.value)
    assert len(handler.requests) == len(provider.retry_waits) + 1
