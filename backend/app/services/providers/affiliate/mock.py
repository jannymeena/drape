"""Dev affiliate provider — a small deterministic catalog so the whole Shop
tab runs end-to-end without an AWIN account. Prices are stable except the
items in _PRICE_DROPS, which lets the wishlist price-drop path demo in dev."""
from __future__ import annotations

from app.services.providers.affiliate.base import AffiliateProduct, AffiliateProvider

_CDN = "https://cdn.drape.local/products"

_CATALOG: list[AffiliateProduct] = [
    AffiliateProduct("mock_001", "White Linen Shirt", "Everlane", "tops", 6800, "CAD", f"{_CDN}/001.jpg", "https://shop.example/001", "Everlane"),
    AffiliateProduct("mock_002", "Black Turtleneck", "Uniqlo", "tops", 3990, "CAD", f"{_CDN}/002.jpg", "https://shop.example/002", "Uniqlo"),
    AffiliateProduct("mock_003", "Striped Breton Tee", "Sézane", "tops", 7500, "CAD", f"{_CDN}/003.jpg", "https://shop.example/003", "Sézane"),
    AffiliateProduct("mock_004", "Navy Chinos", "J.Crew", "bottoms", 9800, "CAD", f"{_CDN}/004.jpg", "https://shop.example/004", "J.Crew"),
    AffiliateProduct("mock_005", "Wide-Leg Trousers", "Aritzia", "bottoms", 12800, "CAD", f"{_CDN}/005.jpg", "https://shop.example/005", "Aritzia"),
    AffiliateProduct("mock_006", "Dark Straight Jeans", "Levi's", "bottoms", 10800, "CAD", f"{_CDN}/006.jpg", "https://shop.example/006", "Levi's"),
    AffiliateProduct("mock_007", "White Leather Sneakers", "Veja", "shoes", 19500, "CAD", f"{_CDN}/007.jpg", "https://shop.example/007", "Veja"),
    AffiliateProduct("mock_008", "Black Ankle Boots", "Blundstone", "shoes", 24900, "CAD", f"{_CDN}/008.jpg", "https://shop.example/008", "Blundstone"),
    AffiliateProduct("mock_009", "Camel Overcoat", "COS", "outerwear", 29000, "CAD", f"{_CDN}/009.jpg", "https://shop.example/009", "COS"),
    AffiliateProduct("mock_010", "Trench Coat", "London Fog", "outerwear", 22000, "CAD", f"{_CDN}/010.jpg", "https://shop.example/010", "London Fog"),
    AffiliateProduct("mock_011", "Midi Wrap Dress", "Reformation", "dresses", 21800, "CAD", f"{_CDN}/011.jpg", "https://shop.example/011", "Reformation"),
    AffiliateProduct("mock_012", "Leather Belt", "Fossil", "accessories", 4500, "CAD", f"{_CDN}/012.jpg", "https://shop.example/012", "Fossil"),
]

# external_id -> live price (cents). Cheaper than catalog = a price drop.
_PRICE_DROPS = {"mock_009": 23200}


class MockAffiliateProvider(AffiliateProvider):
    def catalog(self) -> list[AffiliateProduct]:
        return list(_CATALOG)

    def current_price_cents(self, external_id: str) -> int | None:
        if external_id in _PRICE_DROPS:
            return _PRICE_DROPS[external_id]
        for p in _CATALOG:
            if p.external_id == external_id:
                return p.price_cents
        return None
