"""§5.5.1 / Tier 1.1 — derive a coarse, PIPEDA-safe fit profile from measurements.

The privacy contract, in one place:

  * Raw centimetres NEVER leave our infrastructure. This module reduces them
    to coarse categorical descriptors — body shape, height band, build —
    server-side, at submit time, while the plaintext is already in hand.
  * Only the derived block may enter an AI prompt, and only when the user has
    flipped the separate `use_measurements_for_fit` consent (default off).
    The consent gate lives in `measurements_service.fit_profile_for_user` —
    every prompt-side consumer goes through it.
  * The derived profile is stored on `user_measurements.fit_profile` and dies
    with the row (DELETE /account cascades).

Thresholds are deliberately coarse heuristics (v1): they only need to be
right enough to steer silhouette advice, not to describe a body.
"""
from __future__ import annotations

from typing import Optional

# Height bands (cm) — gender-neutral, coarse on purpose.
_PETITE_MAX_CM = 160.0
_TALL_MIN_CM = 178.0

# Body shape: ratios between chest, waist and hips.
_WAIST_DEFINED_RATIO = 0.80  # waist noticeably smaller than chest & hips
_CHEST_HIP_MARGIN = 1.05  # >5% difference = a directional shape

# Build: shoulder width relative to height.
_SLIM_MAX_RATIO = 0.245
_BROAD_MIN_RATIO = 0.265


def _body_shape(chest: float, waist: float, hips: float) -> str:
    balanced = max(chest, hips) <= min(chest, hips) * _CHEST_HIP_MARGIN
    if balanced and waist <= min(chest, hips) * _WAIST_DEFINED_RATIO:
        return "hourglass"
    if chest > hips * _CHEST_HIP_MARGIN:
        return "inverted_triangle"
    if hips > chest * _CHEST_HIP_MARGIN:
        return "triangle"
    return "rectangle"


def _height_band(height: float) -> str:
    if height < _PETITE_MAX_CM:
        return "petite"
    if height > _TALL_MIN_CM:
        return "tall"
    return "average"


def _build(shoulders: float, height: float) -> str:
    ratio = shoulders / height
    if ratio < _SLIM_MAX_RATIO:
        return "slim"
    if ratio > _BROAD_MIN_RATIO:
        return "broad"
    return "regular"


def derive(measurements: dict) -> Optional[dict]:
    """Coarse fit profile from a plaintext measurements dict (metric cm).

    Each descriptor is derived independently and included only when its
    inputs are present; returns None when nothing can be derived at all.
    Output values are categorical strings — never numbers.
    """
    profile: dict = {}

    height = measurements.get("height_cm")
    chest = measurements.get("chest_cm")
    waist = measurements.get("waist_cm")
    hips = measurements.get("hips_cm")
    shoulders = measurements.get("shoulders_cm")

    if chest and waist and hips:
        profile["body_shape"] = _body_shape(chest, waist, hips)
    if height:
        profile["height_band"] = _height_band(height)
    if shoulders and height:
        profile["build"] = _build(shoulders, height)

    return profile or None


def to_prompt_block(profile: Optional[dict]) -> str:
    """Render the derived profile as the outfit prompt's 'Fit:' line.

    e.g. 'Fit: tall, broad build, inverted triangle shape — favor cuts and
    silhouettes that flatter this.' Empty string when there is no profile —
    the caller (via the consent gate) decides whether one exists at all.
    """
    if not profile:
        return ""
    bits = []
    if profile.get("height_band"):
        bits.append(profile["height_band"])
    if profile.get("build"):
        bits.append(f"{profile['build']} build")
    if profile.get("body_shape"):
        bits.append(f"{profile['body_shape'].replace('_', ' ')} shape")
    if not bits:
        return ""
    return f"Fit: {', '.join(bits)} — favor cuts and silhouettes that flatter this.\n"
