"""AffiliateProvider interface (7a) — product catalog + live prices.

Mock in dev (seeded catalog); real AWIN lands in Tier 3.4 / item 11e.
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


@dataclass(frozen=True)
class AffiliateProduct:
    external_id: str
    name: str
    brand: str
    category: str  # tops|bottoms|shoes|outerwear|dresses|accessories
    price_cents: int
    currency: str
    image_url: str
    product_url: str
    retailer: str


class AffiliateProvider(ABC):
    @abstractmethod
    def catalog(self) -> list[AffiliateProduct]:
        """Full product set to sync into the local `products` table."""

    @abstractmethod
    def current_price_cents(self, external_id: str) -> int | None:
        """Live price for one product (None = unknown/delisted)."""
