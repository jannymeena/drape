"""What image.uploaded logs: size in bytes and in pixels."""

from __future__ import annotations

import io
from unittest.mock import MagicMock

import structlog.testing
from PIL import Image

from app.services.providers.image.base import image_dimensions
from app.services.providers.image.local_fs import LocalFsStorage
from app.services.providers.image.s3 import S3ImageStorage


def _jpeg(size=(683, 1024)) -> bytes:
    out = io.BytesIO()
    Image.new("RGB", size, (90, 90, 90)).save(out, format="JPEG")
    return out.getvalue()


def _uploaded(logs) -> dict:
    [event] = [e for e in logs if e["event"] == "image.uploaded"]
    return event


def test_local_logs_the_photos_size_in_bytes_and_pixels(tmp_path):
    photo = _jpeg()
    storage = LocalFsStorage(root=tmp_path, base_url="http://x/images")

    with structlog.testing.capture_logs() as logs:
        storage.upload(content=photo, content_type="image/jpeg", key_hint="w/1")

    event = _uploaded(logs)
    assert event["bytes"] == len(photo)
    assert (event["width"], event["height"]) == (683, 1024)


def test_s3_logs_the_photos_size_in_bytes_and_pixels(monkeypatch):
    monkeypatch.setattr("boto3.client", lambda *a, **k: MagicMock())
    storage = S3ImageStorage(bucket="b", region="ca-central-1")
    shot = io.BytesIO()
    Image.new("RGBA", (896, 1120)).save(shot, format="PNG")

    with structlog.testing.capture_logs() as logs:
        storage.upload(content=shot.getvalue(), content_type="image/png", key_hint="w/1")

    event = _uploaded(logs)
    assert (event["width"], event["height"]) == (896, 1120)


def test_bytes_that_arent_an_image_log_no_dimensions_and_still_store(tmp_path):
    storage = LocalFsStorage(root=tmp_path, base_url="http://x/images")

    with structlog.testing.capture_logs() as logs:
        url = storage.upload(content=b"not-an-image", content_type="image/jpeg", key_hint="w/1")

    event = _uploaded(logs)
    assert (event["width"], event["height"]) == (None, None)
    assert storage.read(url=url) == (b"not-an-image", "image/jpeg")


def test_dimensions_come_from_the_header_alone():
    # A truncated file still has its header: the size is known.
    assert image_dimensions(_jpeg((400, 500))[:2048]) == (400, 500)
    assert image_dimensions(b"") == (None, None)
