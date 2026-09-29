"""AwinProvider (item 11e) — feed list, gzipped CSV parsing, curation, caching.

The real httpx layer runs against httpx.MockTransport serving a canned feed
list and gzipped feed CSVs.
"""
from __future__ import annotations

import csv
import gzip
import io

import httpx
import pytest

from app.services.providers.affiliate import awin
from app.services.providers.affiliate.awin import AwinProvider, categorize
from app.services.providers.affiliate.base import AffiliateProviderError

_LIST_HEADER = [
    "Advertiser ID", "Advertiser Name", "Primary Region", "Membership Status",
    "Feed ID", "Feed Name", "Language", "Vertical", "Last Checked",
    "Last Imported", "No of products", "URL",
]


def _csv(header: list[str], rows: list[dict]) -> str:
    out = io.StringIO()
    writer = csv.DictWriter(out, fieldnames=header)
    writer.writeheader()
    writer.writerows(rows)
    return out.getvalue()


def _feed_list(*feeds: tuple[str, str, str]) -> str:
    return _csv(
        _LIST_HEADER,
        [
            {"Advertiser ID": adv, "Feed ID": fid, "Membership Status": status}
            for adv, fid, status in feeds
        ],
    )


def _row(pid: str, **overrides) -> dict:
    row = {
        "aw_product_id": pid,
        "product_name": f"Product {pid}",
        "brand_name": "boohoo",
        "merchant_name": "boohoo (US & Canada)",
        "search_price": "24.00",
        "currency": "",
        "aw_deep_link": f"https://www.awin1.com/pclick.php?p={pid}",
        "aw_image_url": f"https://images2.productserve.com/{pid}.jpg",
        "merchant_image_url": f"https://media.boohoo.com/{pid}.jpg",
        "category_name": "Women's Tops",
        "merchant_category": "Tops",
        "merchant_product_category_path": "",
        "stock_status": "in stock",
    }
    row.update(overrides)
    return row


def _feed(rows: list[dict]) -> bytes:
    return gzip.compress(_csv(list(awin._COLUMNS), rows).encode())


class _Upstream:
    """MockTransport handler: one feed list + gzipped feeds by feed ID."""

    def __init__(self, feed_list: str, feeds: dict[str, bytes]) -> None:
        self.feed_list = feed_list
        self.feeds = feeds
        self.requests: list[str] = []
        self.fail = False

    def __call__(self, request: httpx.Request) -> httpx.Response:
        path = request.url.path
        self.requests.append(path)
        if self.fail:
            return httpx.Response(503)
        if "/datafeed/list/apikey/feedkey" in path:
            return httpx.Response(200, text=self.feed_list)
        for fid, body in self.feeds.items():
            if f"/fid/{fid}/" in path:
                return httpx.Response(200, content=body)
        return httpx.Response(404)


@pytest.fixture
def upstream(monkeypatch) -> _Upstream:
    up = _Upstream(
        _feed_list(("60703", "112084", "active")),
        {"112084": _feed([_row("1")])},
    )
    real_client = httpx.Client
    transport = httpx.MockTransport(up)
    monkeypatch.setattr(
        httpx, "Client", lambda **kwargs: real_client(transport=transport)
    )
    return up


def _provider(advertisers: frozenset[str] = frozenset()) -> AwinProvider:
    return AwinProvider(
        publisher_id="999", feed_api_key="feedkey", advertiser_ids=advertisers
    )


# ---------------------------------------------------------------------------
# Row mapping
# ---------------------------------------------------------------------------


def test_row_maps_to_product(upstream):
    [p] = _provider().catalog()
    assert p.external_id == "awin_1"
    assert p.category == "tops"
    assert p.price_cents == 2400
    assert p.currency == "USD"  # blank currency column falls back
    assert p.image_url == "https://media.boohoo.com/1.jpg"  # full-size, not proxy
    assert p.product_url.startswith("https://www.awin1.com/")  # tracked link
    assert p.brand == "boohoo"
    assert p.retailer == "boohoo (US & Canada)"


def test_unusable_rows_skipped(upstream):
    upstream.feeds["112084"] = _feed(
        [
            _row("ok"),
            _row("oos", stock_status="out of stock"),
            _row("noprice", search_price=""),
            _row("zero", search_price="0.00"),
            _row("noimg", merchant_image_url="", aw_image_url=""),
            _row("swim", category_name="Swimwear", merchant_category="Bikinis",
                 product_name="Triangle Bikini"),
        ]
    )
    assert [p.external_id for p in _provider().catalog()] == ["awin_ok"]


def test_falls_back_to_proxy_image_and_merchant_brand(upstream):
    upstream.feeds["112084"] = _feed(
        [_row("1", merchant_image_url="", brand_name="", currency="cad")]
    )
    [p] = _provider().catalog()
    assert p.image_url == "https://images2.productserve.com/1.jpg"
    assert p.brand == "boohoo (US & Canada)"
    assert p.currency == "CAD"


@pytest.mark.parametrize(
    ("texts", "expected"),
    [
        (("Men's Shoes",), "shoes"),
        (("Dress Shoes",), "shoes"),
        (("Shirt Dress",), "dresses"),
        (("Coats & Jackets",), "outerwear"),
        (("Jeans",), "bottoms"),
        (("T-Shirts",), "tops"),
        (("Hoodies & Sweatshirts",), "tops"),
        (("Bags & Purses",), "accessories"),
        (("Lingerie",), None),
        (("", "Women > Clothing > Skirts"), "bottoms"),
    ],
)
def test_categorize(texts, expected):
    assert categorize(*texts) == expected


def test_name_used_only_when_category_fields_are_silent(upstream):
    upstream.feeds["112084"] = _feed(
        [
            _row("a", category_name="New In", merchant_category="",
                 product_name="Oversized Denim Jacket"),
            # Category field wins over the name.
            _row("b", category_name="Jeans", product_name="Jeans & Top Set"),
        ]
    )
    cats = {p.external_id: p.category for p in _provider().catalog()}
    assert cats == {"awin_a": "outerwear", "awin_b": "bottoms"}


# ---------------------------------------------------------------------------
# Curation + feed selection
# ---------------------------------------------------------------------------


def test_catalog_capped_per_category_but_prices_kept(upstream, monkeypatch):
    monkeypatch.setattr(awin, "_PER_CATEGORY", 2)
    upstream.feeds["112084"] = _feed(
        [_row(str(i)) for i in range(5)]
        + [_row("j", category_name="Jeans", merchant_category="Jeans")]
    )
    provider = _provider()
    ids = [p.external_id for p in provider.catalog()]
    assert ids == ["awin_0", "awin_1", "awin_j"]
    # Beyond the cap still priced — wishlist checks survive curation rotating.
    assert provider.current_price_cents("awin_4") == 2400


def test_one_card_per_style_but_every_variant_priced(upstream):
    upstream.feeds["112084"] = _feed(
        [
            # SKU style code groups colours and sizes.
            _row("a1", merchant_product_id="HZZ1-105-22", product_name="Vest in Black"),
            _row("a2", merchant_product_id="HZZ1-105-24", product_name="Vest in Black"),
            _row("a3", merchant_product_id="HZZ1-979-22", product_name="Vest in Pink"),
            # No usable SKU: the name minus the " | colour | size" suffix.
            _row("b1", product_name="Cargo Trousers | Khaki | Size 32"),
            _row("b2", product_name="Cargo  trousers | Black | Size 34"),
            _row("c", merchant_product_id="HZZ2-105-22"),
        ]
    )
    provider = _provider()
    assert [p.external_id for p in provider.catalog()] == ["awin_a1", "awin_b1", "awin_c"]
    assert provider.current_price_cents("awin_a3") == 2400
    assert provider.current_price_cents("awin_b2") == 2400


def test_only_allowed_active_feeds_downloaded(upstream):
    upstream.feed_list = _feed_list(
        ("60701", "110265", "active"),
        ("60703", "112084", "active"),
        ("11111", "222", "active"),
        ("60702", "333", "pending"),
    )
    upstream.feeds["110265"] = _feed([_row("man")])
    upstream.feeds["222"] = _feed([_row("other")])
    upstream.feeds["333"] = _feed([_row("pending")])
    ids = {p.external_id for p in _provider(frozenset({"60701", "60703", "60702"})).catalog()}
    assert ids == {"awin_man", "awin_1"}


def test_empty_allowlist_takes_every_active_feed(upstream):
    upstream.feed_list = _feed_list(
        ("60701", "110265", "active"), ("60703", "112084", "active")
    )
    upstream.feeds["110265"] = _feed([_row("man")])
    assert {p.external_id for p in _provider().catalog()} == {"awin_man", "awin_1"}


def test_no_matching_feeds_raises(upstream):
    with pytest.raises(AffiliateProviderError) as exc:
        _provider(frozenset({"404"})).catalog()
    assert exc.value.code == "awin_feed_failed"


# ---------------------------------------------------------------------------
# Caching
# ---------------------------------------------------------------------------


def test_snapshot_cached_between_calls(upstream):
    provider = _provider()
    provider.catalog()
    n = len(upstream.requests)
    provider.catalog()
    assert provider.current_price_cents("awin_1") == 2400
    assert len(upstream.requests) == n


def test_unknown_product_price_is_none(upstream):
    assert _provider().current_price_cents("awin_nope") is None


def test_stale_snapshot_served_when_refresh_fails(upstream, monkeypatch):
    provider = _provider()
    provider.catalog()
    monkeypatch.setattr(awin, "_TTL_S", -1)  # force a refresh
    upstream.fail = True
    assert [p.external_id for p in provider.catalog()] == ["awin_1"]


def test_first_load_failure_raises_and_price_is_unknown(upstream):
    upstream.fail = True
    provider = _provider()
    with pytest.raises(AffiliateProviderError):
        provider.catalog()
    assert provider.current_price_cents("awin_1") is None


def test_failed_load_backs_off_before_retrying(upstream, monkeypatch):
    upstream.fail = True
    provider = _provider()
    with pytest.raises(AffiliateProviderError):
        provider.catalog()
    n = len(upstream.requests)
    with pytest.raises(AffiliateProviderError):
        provider.catalog()
    assert len(upstream.requests) == n  # no second download inside the window
    monkeypatch.setattr(awin, "_RETRY_S", -1)
    upstream.fail = False
    assert [p.external_id for p in provider.catalog()] == ["awin_1"]
