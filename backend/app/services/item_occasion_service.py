"""Which occasions each wardrobe piece suits — the filter in front of the
stylist.

Every piece is classified with every occasion in the rulebook
(`app/data/occasion_rules.yaml`) it genuinely suits, by a cheap model from
what the piece is (name, category, type, colour, pattern, material,
formality, season, description). The result lives on
`WardrobeItem.occasions`; null means not classified yet.

Classification is lazy: `ensure_classified` runs just before a piece is
styled, in batches of `_BATCH` per call, so a wardrobe is classified once
and only re-asked about pieces that changed (`wardrobe_service.update_item`
clears the field when what the piece is changes). An AI outage or a garbled
reply leaves pieces unclassified; `suits` keeps those, so a classification
failure never hides a piece from the stylist.

`other` is the catch-all occasion: everything suits it, so it is never
asked about and never filters.
"""
from __future__ import annotations

import json
import re
from typing import Optional, Sequence

import structlog
from sqlalchemy.orm import Session

from app.core.config import settings
from app.data import occasion_rules
from app.db.models import WardrobeItem
from app.services.providers.ai.base import AIProvider, AIProviderError

_log = structlog.get_logger("item_occasions")

CATCH_ALL = "other"

# Pieces per classification call: one short line each in and out.
_BATCH = 40

_JSON_OBJECT_RE = re.compile(r"\{.*\}", re.DOTALL)

# Fields that say what a piece is; changing one re-classifies it.
CLASSIFIED_FIELDS = frozenset(
    {"name", "category", "subcategory", "color_name", "pattern", "material", "formality", "season", "description"}
)


def vocabulary() -> list[str]:
    """The occasions a piece is classified with: the rulebook's, less the
    catch-all."""
    return [k for k in occasion_rules.occasion_keys() if k != CATCH_ALL]


def suits(item: WardrobeItem, occasion: str) -> bool:
    """Whether the stylist is offered [item] for [occasion]. Unclassified
    pieces are offered (a failed classification never hides one)."""
    if occasion == CATCH_ALL or item.occasions is None:
        return True
    return occasion in item.occasions


def applicable(items: Sequence[WardrobeItem], occasion: str) -> list[WardrobeItem]:
    """[items] that suit [occasion], in their order."""
    return [i for i in items if suits(i, occasion)]


def _system() -> str:
    occasions = vocabulary()
    lines = "\n".join(
        f"- {k}: {occasion_rules.label(k)}. {occasion_rules.rules().occasions[k].rule.guidance or ''}".rstrip()
        for k in occasions
    )
    return (
        "You classify wardrobe pieces for an outfit-building app: for each "
        "piece, list EVERY occasion below it could genuinely be worn to as "
        "part of a suitable outfit. Shoes, layers and accessories count too: "
        "list the occasions they'd suit in such an outfit. Be honest — a "
        "slogan tee doesn't suit an interview, running shorts don't suit a "
        "wedding — but don't be narrow: plain jeans suit casual, brunch, "
        "travel and many date nights.\n"
        f"Occasions:\n{lines}\n"
        "Reply with ONLY a JSON object — no prose, no markdown — mapping each "
        'piece\'s id to its list, e.g. {"1": ["work", "interview"], "2": '
        '["casual", "beach"]}. Use only the occasion keys above; a piece that '
        "suits none gets []."
    )


def _describe(item: WardrobeItem) -> str:
    parts = [
        item.category,
        item.subcategory or "",
        item.color_name or "",
        item.pattern or "",
        item.material or "",
        item.formality or "",
        "/".join(item.season) if item.season else "",
    ]
    line = f'"{item.name}" [{" | ".join(p for p in parts if p)}]'
    if item.description:
        line += f" — {item.description[:200]}"
    return line


def _parse(text: str) -> dict:
    match = _JSON_OBJECT_RE.search(text or "")
    if match is None:
        raise ValueError("no JSON object in the reply")
    data = json.loads(match.group(0))
    if not isinstance(data, dict):
        raise ValueError("reply is not an object")
    return data


async def _classify_batch(
    ai: AIProvider, batch: Sequence[WardrobeItem], *, model: Optional[str]
) -> int:
    """Classifies [batch] in one call; returns how many pieces got an
    answer. Pieces the reply leaves out stay unclassified."""
    refs = {str(n): item for n, item in enumerate(batch, start=1)}
    prompt = "Pieces:\n" + "\n".join(f"{ref}: {_describe(item)}" for ref, item in refs.items())
    try:
        text = await ai.chat(
            [{"role": "user", "content": prompt}],
            model=model,
            system=_system(),
            max_tokens=40 * len(batch) + 200,
        )
        data = _parse(text)
    except AIProviderError as exc:
        _log.warning("item_occasions.ai_failed", code=exc.code, error=str(exc))
        return 0
    except ValueError as exc:  # incl. JSONDecodeError
        _log.warning("item_occasions.parse_failed", error=str(exc))
        return 0
    known = set(vocabulary())
    done = 0
    for ref, item in refs.items():
        answer = data.get(ref)
        if not isinstance(answer, list):
            continue
        item.occasions = sorted({o for o in answer if isinstance(o, str) and o in known})
        done += 1
    return done


async def ensure_classified(
    db: Session,
    *,
    ai: AIProvider,
    items: Sequence[WardrobeItem],
    model: Optional[str] = None,
) -> None:
    """Classifies the pieces of [items] that aren't yet, a batch per call
    (with the cheap tagging model unless [model] says otherwise), and saves
    them. Best-effort: failures leave pieces unclassified."""
    model = model or settings.catalog_tag_model
    todo = [i for i in items if i.occasions is None]
    if not todo:
        return
    done = 0
    for start in range(0, len(todo), _BATCH):
        done += await _classify_batch(ai, todo[start : start + _BATCH], model=model)
    if done:
        db.commit()
    _log.info("item_occasions.classified", asked=len(todo), classified=done)
