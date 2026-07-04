"""Real AWIN provider — Tier 3.4 / item 11e. Blocked on the affiliate
account + product-data-source decision; raises until implemented."""
from __future__ import annotations

from app.services.providers.affiliate.base import AffiliateProduct, AffiliateProvider


class AwinProvider(AffiliateProvider):
    def __init__(self, *, api_key: str) -> None:
        self._api_key = api_key

    def catalog(self) -> list[AffiliateProduct]:
        raise NotImplementedError("AwinProvider lands in 11e (Tier 3.4)")

    def current_price_cents(self, external_id: str) -> int | None:
        raise NotImplementedError("AwinProvider lands in 11e (Tier 3.4)")
