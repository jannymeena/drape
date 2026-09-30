"""Loads and applies `occasion_rules.yaml` — what a finished outfit is, per
occasion and per audience (menswear / womenswear).

The YAML is validated at import, so a bad edit stops the app from booting
rather than surfacing mid-request. Everything outfit generation needs from the
rules goes through the helpers here: the prompt block, the completeness check,
the roles a shop gap-fill should offer, and pairs that never go together.
"""
from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Literal, Optional

import yaml
from pydantic import BaseModel, ConfigDict, Field

Role = Literal["top", "bottom", "dress", "outerwear", "shoes", "accessory"]
Formality = Literal["casual", "smart_casual", "formal"]

# Wardrobe/outfit category -> role.
ROLE_BY_CATEGORY: dict[str, str] = {
    "tops": "top",
    "bottoms": "bottom",
    "dresses": "dress",
    "outerwear": "outerwear",
    "shoes": "shoes",
    "accessories": "accessory",
    "bags": "accessory",
    "jewelry": "accessory",
}
CATEGORY_BY_ROLE: dict[str, str] = {
    "top": "tops",
    "bottom": "bottoms",
    "dress": "dresses",
    "outerwear": "outerwear",
    "shoes": "shoes",
    "accessory": "accessories",
}

_RULES_PATH = Path(__file__).with_name("occasion_rules.yaml")


class _Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class Rule(_Strict):
    complete_when: list[list[Role]] = Field(min_length=1)
    optional: list[Role] = []
    formality: list[Formality] = []
    guidance: str = ""
    avoid: list[str] = []


class RuleOverride(_Strict):
    """A menswear / womenswear variant: only the fields that differ."""

    complete_when: Optional[list[list[Role]]] = Field(default=None, min_length=1)
    optional: Optional[list[Role]] = None
    formality: Optional[list[Formality]] = None
    guidance: Optional[str] = None
    avoid: Optional[list[str]] = None


class OccasionDef(_Strict):
    label: str
    daily: bool = False
    rule: Rule
    mens: Optional[RuleOverride] = None
    womens: Optional[RuleOverride] = None


class RulesFile(_Strict):
    never_together: list[list[Role]] = []
    occasions: dict[str, OccasionDef] = Field(min_length=1)


@lru_cache(maxsize=1)
def rules() -> RulesFile:
    return RulesFile.model_validate(yaml.safe_load(_RULES_PATH.read_text()))


# Validate at import: a broken rules file fails at startup, not per request.
rules()


def occasion_keys() -> list[str]:
    """Every occasion, in file order (the app's display order)."""
    return list(rules().occasions)


def daily_occasions() -> tuple[str, ...]:
    return tuple(k for k, o in rules().occasions.items() if o.daily)


def label(occasion: str) -> str:
    return rules().occasions[occasion].label


def rule_for(occasion: str, shopping_style: Optional[str]) -> Rule:
    """The occasion's rule with the wearer's audience variant applied
    (menswear / womenswear shoppers; everyone else gets the base rule)."""
    spec = rules().occasions[occasion]
    override = {"mens": spec.mens, "womens": spec.womens}.get(shopping_style or "")
    if override is None:
        return spec.rule
    return spec.rule.model_copy(update=override.model_dump(exclude_none=True))


def roles_of(categories) -> set[str]:
    return {ROLE_BY_CATEGORY[c] for c in categories if c in ROLE_BY_CATEGORY}


def missing_roles(rule: Rule, have: set[str], offered: set[str]) -> list[str]:
    """Roles on `offered` the outfit should still add to reach the nearest of
    the rule's shapes — the one with the fewest roles nothing on offer can
    fill, then the fewest missing. Empty when the outfit is complete or
    nothing on offer would bring it closer. (A menswear wedding look with no
    shoes anywhere still gets asked for its missing top.)"""
    best: Optional[tuple[tuple[int, int], list[str]]] = None
    for shape in rule.complete_when:
        need = [r for r in shape if r not in have]
        if not need:
            return []
        fillable = [r for r in need if r in offered]
        key = (len(need) - len(fillable), len(need))
        if best is None or key < best[0]:
            best = (key, fillable)
    return best[1] if best else []


def gap(rule: Rule, owned: set[str]) -> tuple[list[str], int]:
    """(roles a shop gap-fill should offer, how many pieces the outfit needs
    from them) so the wardrobe can complete the look: the missing roles of
    the nearest shapes — ties all offered, so a womenswear wardrobe with no
    bottoms is offered bottoms *and* dresses. ([], 0) when already complete."""
    needs = [[r for r in shape if r not in owned] for shape in rule.complete_when]
    fewest = min(len(n) for n in needs)
    if fewest == 0:
        return [], 0
    roles: list[str] = []
    for need in needs:
        if len(need) == fewest:
            roles += [r for r in need if r not in roles]
    return roles, fewest


def clashes(roles: set[str]) -> list[tuple[str, str]]:
    """`never_together` pairs present in an outfit's roles."""
    return [(a, b) for a, b in rules().never_together if a in roles and b in roles]


def _human(roles: list[str]) -> str:
    return " + ".join(roles)


def prompt_block(occasion: str, rule: Rule) -> str:
    """The occasion's rulebook entry, as the stylist reads it."""
    shapes = "; or ".join(_human(s) for s in rule.complete_when)
    lines = [
        f"Occasion: {label(occasion)}.",
        f"A complete outfit for it is: {shapes}.",
    ]
    if rule.optional:
        lines.append(f"Optional, only if it improves the look: {', '.join(rule.optional)}.")
    if rule.formality:
        lines.append(f"Formality: {' or '.join(f.replace('_', ' ') for f in rule.formality)}.")
    if rule.guidance:
        lines.append(f"Styling: {rule.guidance}")
    if rule.avoid:
        lines.append(f"Avoid: {'; '.join(rule.avoid)}.")
    return "\n".join(lines)
