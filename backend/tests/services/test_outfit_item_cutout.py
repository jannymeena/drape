"""Outfit pieces carry the wardrobe item's cut-out and dress priority."""

from __future__ import annotations

from app.services.outfit_service import _to_outfit_item
from tests.factories import make_wardrobe_item


def test_outfit_piece_carries_the_cut_out(db, make_user):
    item = make_wardrobe_item(db, make_user(), category="outerwear")
    item.subcategory = "trench"
    item.cutout_url = "http://img/cut.webp"
    item.cutout_box = [0.04, 0.2, 0.92, 0.6]

    piece = _to_outfit_item(item).model_dump(mode="json")

    assert piece["cutout_url"] == "http://img/cut.webp"
    assert piece["cutout_box"] == [0.04, 0.2, 0.92, 0.6]
    assert piece["subcategory"] == "trench"
    assert piece["dress_priority"] == 900


def test_a_piece_without_one_says_so(db, make_user):
    piece = _to_outfit_item(make_wardrobe_item(db, make_user()))
    assert piece.cutout_url is None and piece.cutout_box is None
    assert piece.dress_priority == 600
