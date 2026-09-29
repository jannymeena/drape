"""Real AWIN provider (item 11e) — product catalog from AWIN product feeds.

The feed list (`/datafeed/list`) maps the joined advertisers to feed IDs;
each feed is downloaded as gzipped CSV and streamed through a temp file (the
feeds run to ~100k rows). Only a curated slice reaches the shop — at most
`_PER_CATEGORY` in-stock styles per advertiser per Zoura category, one card
per style (every size and colour is its own feed row) — because the feed
endpoint returns the full product table unpaginated. Prices for *every*
in-stock row are kept so wishlist price checks survive the curated slice
rotating. Feeds refresh daily upstream, so the snapshot is cached in memory
for `_TTL_S`; a failed refresh keeps serving the stale snapshot and holds off
retrying for `_RETRY_S`.
"""
from __future__ import annotations

import csv
import gzip
import re
import tempfile
import threading
import time
from dataclasses import dataclass
from decimal import Decimal, InvalidOperation
from typing import Iterator

import httpx
import structlog

from app.services.providers.affiliate.base import (
    AffiliateProduct,
    AffiliateProvider,
    AffiliateProviderError,
)

_log = structlog.get_logger("provider.affiliate.awin")

_BASE_URL = "https://productdata.awin.com/datafeed"
_TIMEOUT_S = httpx.Timeout(30.0, read=120.0)
_TTL_S = 6 * 3600
# After a failed load, wait this long before hitting AWIN again — a load is a
# multi-second download that every shop request would otherwise retry.
_RETRY_S = 300
_PER_CATEGORY = 25
# Feeds are US & Canada; AWIN only fills `currency` on some feeds.
_DEFAULT_CURRENCY = "USD"

_COLUMNS = (
    "aw_product_id",
    "merchant_product_id",
    "product_name",
    "brand_name",
    "merchant_name",
    "search_price",
    "currency",
    "aw_deep_link",
    "aw_image_url",
    "merchant_image_url",
    "category_name",
    "merchant_category",
    "merchant_product_category_path",
    "stock_status",
)

# Checked in order: "dress shoes" is shoes, "shirt dress" is a dress.
_CATEGORY_PATTERNS: tuple[tuple[str, re.Pattern[str]], ...] = tuple(
    (cat, re.compile(rf"\b(?:{words})\b"))
    for cat, words in (
        ("shoes", r"shoes?|footwear|sneakers?|trainers?|boots?|sandals?|heels?|loafers?|slippers?|mules?|slides?|flats"),
        ("dresses", r"dress(?:es)?|jumpsuits?|playsuits?|rompers?"),
        ("outerwear", r"coats?|jackets?|blazers?|parkas?|gilets?|puffers?|outerwear|trench"),
        ("bottoms", r"jeans?|trousers?|pants|shorts|skirts?|leggings?|joggers?|bottoms|cargos?"),
        ("tops", r"tops?|t-shirts?|tees?|shirts?|blouses?|sweaters?|jumpers?|hoodies?|sweatshirts?|cardigans?|knitwear|polos?|bodysuits?|camis?|vests?|tanks?"),
        ("accessories", r"accessor(?:y|ies)|bags?|handbags?|belts?|hats?|caps?|beanies?|scarf|scarves|jewell?ery|necklaces?|earrings?|bracelets?|rings?|sunglasses|watches|wallets?|gloves?"),
    )
)


def categorize(*texts: str) -> str | None:
    """First Zoura category whose keywords appear in `texts` (lowercased)."""
    haystack = " ".join(t for t in texts if t).lower()
    for cat, pattern in _CATEGORY_PATTERNS:
        if pattern.search(haystack):
            return cat
    return None


def _price_cents(raw: str) -> int | None:
    try:
        cents = int((Decimal(raw.strip()) * 100).to_integral_value())
    except (InvalidOperation, AttributeError):
        return None
    return cents if cents > 0 else None


def _in_stock(row: dict[str, str]) -> bool:
    status = (row.get("stock_status") or "").strip().lower()
    return not status or status in {"in stock", "instock", "in_stock", "1", "yes", "true"}


def _style_key(row: dict[str, str]) -> str:
    """Groups a style's size/colour variants. AWIN leaves parent_product_id
    empty on these feeds; boohoo SKUs are STYLE-COLOUR-SIZE, so the style code
    is the SKU prefix. Otherwise the name minus a " | colour | size" suffix."""
    sku = (row.get("merchant_product_id") or "").strip()
    if "-" in sku:
        return "sku:" + sku.split("-", 1)[0].lower()
    name = (row.get("product_name") or "").split("|", 1)[0]
    return "name:" + " ".join(name.lower().split())


def _to_product(row: dict[str, str], advertiser_id: str | None = None) -> AffiliateProduct | None:
    """Feed row -> product, or None when it can't be shown in the shop."""
    ext = (row.get("aw_product_id") or "").strip()
    name = (row.get("product_name") or "").strip()
    link = (row.get("aw_deep_link") or "").strip()
    # merchant_image_url is full-size; aw_image_url is AWIN's 200px proxy.
    image = (row.get("merchant_image_url") or row.get("aw_image_url") or "").strip()
    price = _price_cents(row.get("search_price") or "")
    if not (ext and name and link and image and price):
        return None
    # Category fields first; the product name only when they say nothing.
    category = categorize(
        row.get("category_name", ""),
        row.get("merchant_category", ""),
        row.get("merchant_product_category_path", ""),
    ) or categorize(name)
    if category is None:
        return None  # swimwear, lingerie, beauty, ... — outside the shop's taxonomy
    merchant = (row.get("merchant_name") or "").strip()
    return AffiliateProduct(
        external_id=f"awin_{ext}",
        name=name,
        brand=(row.get("brand_name") or "").strip() or merchant,
        category=category,
        price_cents=price,
        currency=(row.get("currency") or "").strip().upper() or _DEFAULT_CURRENCY,
        image_url=image,
        product_url=link,
        retailer=merchant,
        advertiser_id=advertiser_id,
    )


@dataclass(frozen=True)
class _Snapshot:
    catalog: list[AffiliateProduct]
    prices: dict[str, int]  # external_id -> cents, every in-stock row
    loaded_at: float


class AwinProvider(AffiliateProvider):
    def __init__(
        self,
        *,
        publisher_id: str,
        feed_api_key: str,
        advertiser_ids: frozenset[str] = frozenset(),
    ) -> None:
        self._publisher_id = publisher_id
        self._feed_api_key = feed_api_key
        self._advertiser_ids = advertiser_ids
        self._snapshot: _Snapshot | None = None
        self._failed_at: float | None = None
        self._lock = threading.Lock()

    def catalog(self) -> list[AffiliateProduct]:
        return list(self._current().catalog)

    def current_price_cents(self, external_id: str) -> int | None:
        try:
            return self._current().prices.get(external_id)
        except AffiliateProviderError:
            return None  # unknown — the wishlist just shows no drop

    # ------------------------------------------------------------------

    def _current(self) -> _Snapshot:
        with self._lock:
            snap = self._snapshot
            now = time.monotonic()
            if snap is not None and now - snap.loaded_at < _TTL_S:
                return snap
            if self._failed_at is not None and now - self._failed_at < _RETRY_S:
                if snap is None:
                    raise AffiliateProviderError(
                        "awin_feed_failed", "AWIN feed load failed recently; retry pending"
                    )
                return snap
            try:
                self._snapshot = self._load()
                self._failed_at = None
            except (httpx.HTTPError, OSError, ValueError, csv.Error, AffiliateProviderError) as exc:
                self._failed_at = now
                if snap is None:
                    raise AffiliateProviderError(
                        "awin_feed_failed", f"AWIN feed load failed: {exc}"
                    ) from exc
                _log.warning("awin.refresh_failed_serving_stale", error=str(exc))
                return snap
            return self._snapshot

    def _load(self) -> _Snapshot:
        with httpx.Client(timeout=_TIMEOUT_S, follow_redirects=True) as client:
            feeds = self._feed_ids(client)
            if not feeds:
                raise AffiliateProviderError(
                    "awin_no_feeds",
                    "No active AWIN feeds for the configured advertisers",
                )
            catalog: list[AffiliateProduct] = []
            prices: dict[str, int] = {}
            for advertiser_id, feed_id in feeds:
                taken: dict[str, int] = {}
                styles: set[str] = set()
                rows = 0
                for row in self._feed_rows(client, feed_id):
                    rows += 1
                    if not _in_stock(row):
                        continue
                    product = _to_product(row, advertiser_id)
                    if product is None:
                        continue
                    prices[product.external_id] = product.price_cents
                    style = _style_key(row)
                    if style in styles or taken.get(product.category, 0) >= _PER_CATEGORY:
                        continue
                    styles.add(style)
                    taken[product.category] = taken.get(product.category, 0) + 1
                    catalog.append(product)
                _log.info(
                    "awin.feed_loaded",
                    advertiser_id=advertiser_id,
                    feed_id=feed_id,
                    rows=rows,
                    selected=sum(taken.values()),
                )
        return _Snapshot(catalog=catalog, prices=prices, loaded_at=time.monotonic())

    def _feed_ids(self, client: httpx.Client) -> list[tuple[str, str]]:
        """(advertiser_id, feed_id) for every active, allowed feed."""
        resp = client.get(f"{_BASE_URL}/list/apikey/{self._feed_api_key}")
        resp.raise_for_status()
        feeds: list[tuple[str, str]] = []
        for row in csv.DictReader(resp.text.splitlines()):
            row = {(k or "").strip().lower(): (v or "").strip() for k, v in row.items()}
            advertiser_id = row.get("advertiser id", "")
            feed_id = row.get("feed id", "")
            if not (advertiser_id and feed_id):
                continue
            if row.get("membership status", "active").lower() != "active":
                continue
            if self._advertiser_ids and advertiser_id not in self._advertiser_ids:
                continue
            feeds.append((advertiser_id, feed_id))
        return feeds

    def _feed_rows(self, client: httpx.Client, feed_id: str) -> Iterator[dict[str, str]]:
        url = (
            f"{_BASE_URL}/download/apikey/{self._feed_api_key}/fid/{feed_id}"
            f"/format/csv/language/en/delimiter/%2C/compression/gzip"
            f"/columns/{'%2C'.join(_COLUMNS)}/"
        )
        with tempfile.TemporaryFile() as buf:
            with client.stream("GET", url) as resp:
                resp.raise_for_status()
                for chunk in resp.iter_bytes():
                    buf.write(chunk)
            buf.seek(0)
            with gzip.open(buf, "rt", encoding="utf-8", newline="") as text:
                yield from csv.DictReader(text)
