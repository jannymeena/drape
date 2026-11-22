"""Telling an item's ghost-mannequin shots from the user's own photos.

Both sit in `WardrobeItem.images`. A shot is stored under the key hint
`<item id>-mannequin`, and image storage names files `<key hint>-<hash>.<ext>`
(locally and on S3), so its file name says what it is. The app lays shots
(transparent) on a background and shows photos as they are.
"""

from __future__ import annotations

from uuid import UUID

_MARK = "-mannequin"


def key_hint(user_id: UUID | str, item_id: UUID | str) -> str:
    """Where a mannequin shot for the item is stored."""
    return f"wardrobe/{user_id}/{item_id}{_MARK}"


def is_shot(url: str, item_id: UUID | str) -> bool:
    """Whether [url] is one of the item's mannequin shots."""
    filename = url.rsplit("/", 1)[-1]
    return filename.startswith(f"{item_id}{_MARK}-")
