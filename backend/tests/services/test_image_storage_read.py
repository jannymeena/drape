"""Reading a stored image back (the background image jobs read the photo)."""

from __future__ import annotations

from unittest.mock import MagicMock

from app.services.providers.image.local_fs import LocalFsStorage
from app.services.providers.image.s3 import S3ImageStorage


def test_local_reads_back_what_it_stored(tmp_path):
    storage = LocalFsStorage(root=tmp_path, base_url="http://x/images")
    url = storage.upload(content=b"jpeg-bytes", content_type="image/jpeg", key_hint="w/1")

    assert storage.read(url=url) == (b"jpeg-bytes", "image/jpeg")
    assert storage.read(url="http://x/images/w/missing.jpg") is None
    assert storage.read(url="http://elsewhere/a.jpg") is None


def test_s3_reads_the_object_at_the_url(monkeypatch):
    client = MagicMock()
    client.get_object.return_value = {
        "Body": MagicMock(read=lambda: b"png-bytes"),
        "ContentType": "image/png",
    }
    monkeypatch.setattr("boto3.client", lambda *a, **k: client)
    storage = S3ImageStorage(bucket="b", region="ca-central-1")

    got = storage.read(url="https://b.s3.ca-central-1.amazonaws.com/w/1-abc.png")

    assert got == (b"png-bytes", "image/png")
    client.get_object.assert_called_once_with(Bucket="b", Key="w/1-abc.png")
    assert storage.read(url="https://other.example/x.png") is None
