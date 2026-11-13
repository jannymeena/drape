"""How much of an outfit picture a piece may claim, as a number from 0 to
1000 (bigger = a bigger slot).

The client's outfit layouts never see these numbers: they sort the pieces by
priority and hand them to the slots largest-first, so only the order matters.
Equal numbers mean "same size" — a layout with equal slots is preferred for
them (tops and bottoms tie on purpose, to sit side by side).

The values are spread out in big steps so a new kind of piece can slot in
between without renumbering anything: split a category with a subcategory
override (say a blazer at 850, between outerwear and dresses), and every
outfit — old ones too, since this is resolved when an outfit is read — picks
it up.
"""

from __future__ import annotations

# Wardrobe categories (schemas.wardrobe.Category) and product categories.
_BY_CATEGORY: dict[str, int] = {
    "outerwear": 900,
    "dresses": 800,
    "tops": 600,
    "bottoms": 600,
    "shoes": 400,
    "bags": 300,
    "accessories": 200,
    "jewelry": 100,
}

# Lower-cased subcategory → priority, overriding its category. Empty until a
# category needs splitting.
_BY_SUBCATEGORY: dict[str, int] = {}

# Anything not in the tables: the middle, so it neither dominates nor vanishes.
DEFAULT = 500


def resolve(category: str | None, subcategory: str | None = None) -> int:
    """The priority for a piece of [category] (and optional [subcategory])."""
    if subcategory:
        sub = _BY_SUBCATEGORY.get(subcategory.strip().lower())
        if sub is not None:
            return sub
    return _BY_CATEGORY.get((category or "").strip().lower(), DEFAULT)
