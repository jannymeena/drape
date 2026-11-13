"""Background removal by colour key — no model.

The image model is asked to render the piece on a flat, saturated backdrop
(magenta, or green for pinks and purples), so the backdrop is just "pixels
close to that colour" — or to a darker shade of it, since the model tends to
add a soft drop shadow however it's asked not to:

  * pixels far from the backdrop colour are the piece (opaque);
  * a band just inside the outline is despilled: the backdrop colour bleeds
    into it (reflected light, JPEG colour smear). Each pixel loses the part
    of its colour that leans toward the backdrop, compared with the clean
    piece further in — so shading and patterns survive, the pink cast
    doesn't;
  * then the whole piece is despilled the classic way: shiny leather, glass
    and satin reflect the backdrop anywhere, not just at the outline, so
    any pixel leaning toward the backdrop colour is pulled back. Safe
    because the backdrop is chosen away from the piece's own colour
    (cutout_service.pick_backdrop): on magenta, a magenta lean can only be
    reflection;
  * an edge pixel is a blend of piece and backdrop. Its piece colour is
    taken from the solid piece pixels right next to it, and its alpha is how
    far along the line from backdrop to that colour it sits — so a soft knit
    edge fades out in its own colour, without a pink (or dark) fringe.

Milliseconds and a few MB of memory per 1K image; runs on the smallest
instance. The backdrop actually rendered is read off the image's border (the
model rarely hits the exact hex), and an uneven border is refused rather than
keyed badly.
"""

from __future__ import annotations

import numpy as np
from PIL import Image

from app.services.providers.background_removal.base import (
    BackgroundRemovalError,
    BackgroundRemover,
)

# Colour distance (RGB, 0–255 per channel) from the backdrop: at or over
# _OPAQUE a pixel is solid piece. Under _NOISE it's backdrop whatever its
# neighbours are (render noise, JPEG ringing).
_OPAQUE = 120.0
_NOISE = 20.0

# Where there's no solid piece close by (a thin strap), a plain ramp:
# backdrop at _INNER, piece at _OPAQUE.
_INNER = 45.0

# A shadow on the backdrop is the backdrop colour scaled down — to no less
# than this. (Lower would start taking in black and navy pieces.)
_DARKEST_SHADOW = 0.55

# The rendered backdrop may drift from the one asked for (shade, lighting),
# but not into a different colour.
_MAX_DRIFT = 110.0

# Share of the border that must read as backdrop.
_EVEN_BORDER = 0.9

# The piece must cover at least this share of the image.
_MIN_COVER = 0.02

# Radius (px) the edge colour is borrowed from; width of the despill band,
# and how far past it the clean colour is taken from.
_REACH = 3
_EDGE_BAND = 16
_CORE_REACH = 8


class ChromaKeyRemover(BackgroundRemover):
    def remove(
        self, image: Image.Image, *, backdrop: tuple[int, int, int]
    ) -> Image.Image:
        rgb = np.asarray(image.convert("RGB"), dtype=np.float32)
        key = _rendered_backdrop(rgb, backdrop)
        # The backdrop as it is at each pixel: a shadow of the key where the
        # pixel reads as one (the key scaled down, not below the darkest
        # shadow — under that it's a dark piece), else the key itself.
        shade = (rgb @ key) / float(key @ key)
        shade = np.where(shade >= _DARKEST_SHADOW, np.minimum(shade, 1.0), 1.0)
        behind = shade[..., None] * key
        distance = np.linalg.norm(rgb - behind, axis=2)

        opaque = distance >= _OPAQUE
        if float(opaque.mean()) < _MIN_COVER:
            raise BackgroundRemovalError("no_subject", "Nothing but backdrop.")

        piece = _despill(rgb, opaque, backdrop)

        # The piece colour around each pixel: the mean of the solid pixels
        # within _REACH (none → no estimate).
        weight = _box_sum(opaque.astype(np.float32), _REACH)
        near = weight > 0
        around = np.stack(
            [_box_sum(piece[..., c] * opaque, _REACH) for c in range(3)], axis=2
        ) / np.maximum(weight, 1.0)[..., None]

        # Edge: alpha = how far from the backdrop toward the colour around it.
        toward = around - behind
        reach = np.maximum((toward**2).sum(axis=2), 1.0)
        projected = np.clip(((rgb - behind) * toward).sum(axis=2) / reach, 0.0, 1.0)
        edge = ~opaque & near & (distance > _NOISE)

        # Thin bits with no solid pixel near: ramp, and unmix the colour.
        ramp = np.clip((distance - _INNER) / (_OPAQUE - _INNER), 0.0, 1.0)
        thin = ~opaque & ~near & (ramp > 0)

        alpha = np.zeros(distance.shape, dtype=np.float32)
        alpha[opaque] = 1.0
        alpha[edge] = projected[edge]
        alpha[thin] = ramp[thin]

        colour = np.zeros_like(rgb)
        colour[opaque] = piece[opaque]
        colour[edge] = around[edge]
        colour[thin] = _unmix(rgb, ramp, behind)[thin]

        out = np.dstack([np.clip(colour, 0.0, 255.0), alpha * 255.0])
        return Image.fromarray(np.round(out).astype(np.uint8), "RGBA")


def _rendered_backdrop(
    rgb: np.ndarray, asked: tuple[int, int, int]
) -> np.ndarray:
    """The backdrop colour as rendered: the median of the pixels in a thin
    frame round the image that are near [asked]. Raises when the frame isn't
    that colour, or isn't (mostly) one colour."""
    h, w, _ = rgb.shape
    b = max(2, round(min(h, w) * 0.02))
    frame = np.concatenate(
        [
            rgb[:b].reshape(-1, 3),
            rgb[-b:].reshape(-1, 3),
            rgb[:, :b].reshape(-1, 3),
            rgb[:, -b:].reshape(-1, 3),
        ]
    )
    close = (
        np.linalg.norm(frame - np.asarray(asked, dtype=np.float32), axis=1)
        <= _MAX_DRIFT
    )
    if float(close.mean()) < 0.25:
        raise BackgroundRemovalError(
            "wrong_backdrop", "The backdrop isn't the colour asked for."
        )
    key = np.median(frame[close], axis=0)
    even = float((np.linalg.norm(frame - key, axis=1) <= _INNER).mean())
    if even < _EVEN_BORDER:
        raise BackgroundRemovalError(
            "uneven_backdrop", "The backdrop isn't one flat colour."
        )
    return key


def _box_sum(values: np.ndarray, r: int) -> np.ndarray:
    """Sum over the (2r+1)² square round each pixel (edges clipped), via an
    integral image."""
    padded = np.pad(values, r, mode="constant")
    integral = np.pad(padded.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    k = 2 * r + 1
    return (
        integral[k:, k:] - integral[:-k, k:] - integral[k:, :-k] + integral[:-k, :-k]
    )


def _unmix(rgb: np.ndarray, alpha: np.ndarray, behind: np.ndarray) -> np.ndarray:
    """A pixel at partial alpha is `a·piece + (1−a)·backdrop`: solve for the
    piece."""
    a = alpha[..., None]
    return np.clip((rgb - (1.0 - a) * behind) / np.maximum(a, 1e-3), 0.0, 255.0)


_LUMA = np.array([0.299, 0.587, 0.114], dtype=np.float32)


def _despill(
    rgb: np.ndarray, opaque: np.ndarray, backdrop: tuple[int, int, int]
) -> np.ndarray:
    """Takes the backdrop's cast out of the solid pixels near the outline.

    In chromaticity (colour with brightness divided out), each pixel is
    compared with the clean piece further in (the mean of the solid pixels
    past the band, within reach). Only the part of the difference that
    points toward the backdrop colour is removed; brightness and any other
    colour variation (a stripe, a print) are kept. Then reflections of the
    backdrop are despilled everywhere ([_reflections])."""
    # Solid pixels with a non-solid one within _EDGE_BAND.
    band = opaque & (_box_sum((~opaque).astype(np.float32), _EDGE_BAND) > 0)
    core = opaque & ~band

    reach = _EDGE_BAND + _CORE_REACH
    weight = _box_sum(core.astype(np.float32), reach)
    clean = np.stack(
        [_box_sum(rgb[..., c] * core, reach) for c in range(3)], axis=2
    ) / np.maximum(weight, 1.0)[..., None]

    luma = np.maximum(rgb @ _LUMA, 1.0)[..., None]
    chroma = rgb / luma
    clean_chroma = clean / np.maximum(clean @ _LUMA, 1.0)[..., None]
    key = np.asarray(backdrop, dtype=np.float32)
    key_chroma = key / max(float(key @ _LUMA), 1.0)
    toward = key_chroma - clean_chroma
    toward /= np.maximum(np.linalg.norm(toward, axis=2, keepdims=True), 1e-6)
    lean = np.maximum(((chroma - clean_chroma) * toward).sum(axis=2), 0.0)
    cleaned = (chroma - lean[..., None] * toward) * luma

    out = rgb.copy()
    borrow = band & (weight > 0)
    out[borrow] = cleaned[borrow]
    return np.clip(_reflections(out, backdrop), 0.0, 255.0)


def _reflections(rgb: np.ndarray, backdrop: tuple[int, int, int]) -> np.ndarray:
    """The classic green-screen despill over the whole image: wherever the
    backdrop's strong channels (red+blue for magenta, green for green) all
    stand above its weak ones, they're pulled down to them."""
    strong = [i for i, c in enumerate(backdrop) if c >= 128]
    weak = [i for i, c in enumerate(backdrop) if c < 128]
    if not strong or not weak:
        return rgb
    spill = rgb[..., strong].min(axis=2) - rgb[..., weak].max(axis=2)
    spill = np.maximum(spill, 0.0)
    out = rgb.copy()
    for i in strong:
        out[..., i] -= spill
    return out
