"""Telling an item's mannequin shots from its photos by file name."""

from __future__ import annotations

from uuid import uuid4

from app.services import mannequin_shots

_USER, _ITEM = uuid4(), uuid4()


def _stored(key_hint: str, ext: str = ".png") -> str:
    # What both image stores make of a key hint: <hint>-<sha16><ext>.
    return f"http://cdn/{key_hint}-0123456789abcdef{ext}"


def test_a_shot_is_known_by_its_name():
    url = _stored(mannequin_shots.key_hint(_USER, _ITEM))
    assert mannequin_shots.is_shot(url, _ITEM)
    assert mannequin_shots.is_shot(url, str(_ITEM))


def test_the_users_photo_and_the_cut_out_are_not_shots():
    assert not mannequin_shots.is_shot(_stored(f"wardrobe/{_USER}/{_ITEM}", ".jpg"), _ITEM)
    assert not mannequin_shots.is_shot(
        _stored(f"wardrobe/{_USER}/{_ITEM}-cutout", ".webp"), _ITEM
    )


def test_another_items_shot_is_not_this_items():
    url = _stored(mannequin_shots.key_hint(_USER, uuid4()))
    assert not mannequin_shots.is_shot(url, _ITEM)
