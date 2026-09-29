"""AffiliateProvider interface (7a) — product catalog + live prices.

Mock in dev without AWIN keys (seeded catalog); real AWIN feeds otherwise (11e).
"""
from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


class AffiliateProviderError(Exception):
    """The upstream catalog couldn't be loaded (and nothing cached to serve)."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


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
