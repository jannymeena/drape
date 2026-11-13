"""Dress priority: the 0–1000 number the outfit picture sizes pieces by."""

from __future__ import annotations

from uuid import uuid4

import pytest

from app.schemas.outfit import OutfitItem
from app.schemas.wardrobe import Category
from app.services import dress_priority
from app.services.catalog_service import CATEGORY_BY_ROLE


def test_bigger_pieces_rank_higher():
    order = ["outerwear", "dresses", "tops", "shoes", "bags", "accessories", "jewelry"]
    values = [dress_priority.resolve(c) for c in order]
    assert values == sorted(values, reverse=True)
    assert all(0 <= v <= 1000 for v in values)


def test_tops_and_bottoms_tie_so_they_share_equal_slots():
    assert dress_priority.resolve("tops") == dress_priority.resolve("bottoms")


@pytest.mark.parametrize("category", Category.__args__)
def test_every_wardrobe_category_has_its_own_number(category):
    assert dress_priority.resolve(category) != dress_priority.DEFAULT


@pytest.mark.parametrize("category", sorted(set(CATEGORY_BY_ROLE.values())))
def test_every_product_category_has_its_own_number(category):
    assert dress_priority.resolve(category) != dress_priority.DEFAULT


def test_unknown_goes_in_the_middle():
    assert dress_priority.resolve("capes") == dress_priority.DEFAULT == 500
    assert dress_priority.resolve(None) == 500


def test_a_subcategory_can_split_its_category(monkeypatch):
    monkeypatch.setitem(dress_priority._BY_SUBCATEGORY, "blazer", 850)
    assert dress_priority.resolve("outerwear", "Blazer") == 850
    assert dress_priority.resolve("outerwear", "parka") == 900  # not split


def test_outfit_items_resolve_it_on_read(monkeypatch):
    item = OutfitItem(item_id=uuid4(), name="Coat", category="outerwear")
    assert item.model_dump()["dress_priority"] == 900

    # A stored outfit picks up a re-tuned table: the number isn't frozen in.
    stored = item.model_dump(mode="json")
    monkeypatch.setitem(dress_priority._BY_CATEGORY, "outerwear", 950)
    assert OutfitItem.model_validate(stored).dress_priority == 950
