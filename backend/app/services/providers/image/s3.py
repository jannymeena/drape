from __future__ import annotations

import hashlib
from urllib.parse import urlparse

import boto3
import structlog

from app.services.providers.image.base import ImageStorageProvider

_log = structlog.get_logger("provider.image.s3")


class S3ImageStorage(ImageStorageProvider):
    """Tbd/prd S3-backed storage.

    Object keys are content-addressed: `<key_hint>-<sha16>.<ext>`. Same content
    re-uploaded resolves to the same key, so the PUT is effectively idempotent
    and `delete` is safe to retry.

    Returned URL is the CloudFront base if `cdn_base_url` is set; otherwise
    falls back to the S3 virtual-hosted URL. The bucket itself stays private —
    in prd, CloudFront fronts it via Origin Access Control.
    """

    _EXT = {
        "image/jpeg": ".jpg",
        "image/png": ".png",
        "image/webp": ".webp",
    }

    def __init__(self, *, bucket: str, region: str, cdn_base_url: str | None = None) -> None:
        self._bucket = bucket
        self._region = region
        self._cdn_base_url = cdn_base_url.rstrip("/") if cdn_base_url else None
        self._client = boto3.client("s3", region_name=region)

    def upload(self, *, content: bytes, content_type: str, key_hint: str) -> str:
        ext = self._EXT.get(content_type, "")
        digest = hashlib.sha256(content).hexdigest()[:16]
        key = f"{key_hint}-{digest}{ext}"
        self._client.put_object(
            Bucket=self._bucket,
            Key=key,
            Body=content,
            ContentType=content_type,
        )
        url = self._public_url(key)
        _log.info(
            "image.uploaded",
            backend="s3",
            bucket=self._bucket,
            key=key,
            bytes=len(content),
            content_type=content_type,
        )
        return url

    def delete(self, *, url: str) -> None:
        key = self._key_from_url(url)
        if key is None:
            return None
        self._client.delete_object(Bucket=self._bucket, Key=key)
        _log.info("image.deleted", backend="s3", bucket=self._bucket, key=key)

    def _public_url(self, key: str) -> str:
        if self._cdn_base_url:
            return f"{self._cdn_base_url}/{key}"
        return f"https://{self._bucket}.s3.{self._region}.amazonaws.com/{key}"

    def _key_from_url(self, url: str) -> str | None:
        if self._cdn_base_url and url.startswith(self._cdn_base_url + "/"):
            return url[len(self._cdn_base_url) + 1 :]
        parsed = urlparse(url)
        # Virtual-hosted style: <bucket>.s3.<region>.amazonaws.com/<key>
        if parsed.netloc.startswith(f"{self._bucket}.") and parsed.path:
            return parsed.path.lstrip("/")
        return None
