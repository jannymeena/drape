"""The transparent "cut-out" of a wardrobe piece, for pictures that show
several pieces at once (an outfit laid out on a background in the app).

On upload, the piece's photo is redrawn folded on a flat colour backdrop by
the image model, the backdrop is keyed out (BackgroundRemover — no model),
and the piece is trimmed and centred on a fixed square transparent canvas.
Every cut-out therefore has the same size and margin; the client sizes each
one by its dress priority (dress_priority.py), not by how it was framed.

Alongside the image goes the piece's box on that canvas (fractions of the
side: x, y, width, height), so the client can place it by its real outline.
"""

from __future__ import annotations

import colorsys
import io
from dataclasses import dataclass

import numpy as np
import structlog
from PIL import Image

from app.services.providers.background_removal.base import (
    BackgroundRemovalError,
    BackgroundRemover,
)
from app.services.providers.garment_image.base import (
    GarmentImageError,
    GarmentImageProvider,
)

_log = structlog.get_logger("cutout")

# The fold itself; the backdrop line is added per piece. Folded into a tidy
# block squared up with the frame, shot straight down: the app lays pieces
# side by side in rows, which only looks right when every piece's edges run
# parallel to the picture's (a coat drawn at an angle reads as a diamond and
# leaves empty corners).
FOLDED_PROMPT = "Show this exact garment neatly folded"

# Things that don't fold (a folded trainer comes out crumpled) are laid out
# as they are instead.
LAID_OUT_PROMPT = "Show this exact item neatly arranged, seen from above"
UNFOLDABLE = frozenset({"shoes", "bags", "jewelry", "accessories"})

_ONE = "one single garment only, never a pile or stack of several copies"
_ABOVE = "photographed straight down from directly above"

# The shape each kind of piece is folded or set down in. The picture is a
# little wider than tall and the app packs pieces into two rows (a coat
# across the top, the rest below), which fills it only when the pieces are
# square or wider than tall — a coat folded wide, a top and trousers folded
# into squares, shoes lying on their sides. Tall shapes leave the picture
# half empty.
_SHAPES: dict[str, str] = {
    "outerwear": (
        " in half across its middle, shoulders down to the hem, with the "
        "sleeves folded in behind, so it lies as a wide, short landscape "
        "rectangle clearly wider than tall — about 1.7 times as wide as it "
        f"is tall — as in a shop display: {_ONE}, {_ABOVE}"
    ),
    "tops": (
        " with the sleeves folded in behind into a neat square block, about "
        f"as wide as it is tall, as in a shop display: {_ONE}, {_ABOVE}"
    ),
    "bottoms": (
        " in half lengthwise and then in half again into a compact block "
        f"about as wide as it is tall, as in a shop display: {_ONE}, {_ABOVE}"
    ),
}
_FOLD = f" into a neat flat rectangle, as in a shop display: {_ONE}, {_ABOVE}"

# Shoes as the pair lying on their sides, one above the other — a landscape
# shape, like a pair set down in a flat-lay — even when the photo shows one.
_PAIR = (
    ": the matching pair lying on their sides, one just above the other, "
    f"both toes pointing to the right, {_ABOVE}"
)
_LAY = f", {_ABOVE}"

# Every piece: square to the frame, not turned.
_SQUARE = (
    "Its edges run straight and parallel to the edges of the frame; it is "
    "not rotated, tilted or at an angle."
)

# Side of the square canvas every cut-out is placed on, and the empty margin
# around the piece (each side, as a share of the side).
CANVAS = 1024
MARGIN = 0.04

CONTENT_TYPE = "image/webp"

# Alpha above which a pixel counts as part of the piece.
ALPHA_FLOOR = 25

# Stray specks: blobs smaller than this share of the biggest one are
# cleared, looked for on a grid this many cells across.
SPECK_SHARE = 0.05
SPECK_GRID = 64

# Drawings tried before giving up when the backdrop won't key.
KEY_ATTEMPTS = 2


@dataclass(frozen=True)
class Backdrop:
    name: str
    rgb: tuple[int, int, int]

    @property
    def hex(self) -> str:
        return "#{:02X}{:02X}{:02X}".format(*self.rgb)


MAGENTA = Backdrop("magenta", (255, 0, 255))
GREEN = Backdrop("green", (0, 255, 0))


@dataclass(frozen=True)
class Cutout:
    content: bytes
    content_type: str
    # (x, y, width, height) of the piece on the canvas, each 0–1.
    box: tuple[float, float, float, float]


def pick_backdrop(color_hex: str | None) -> Backdrop:
    """Magenta, unless the piece itself is pink/purple/magenta-ish — then
    green, so the key never eats the piece."""
    rgb = _parse_hex(color_hex)
    if rgb is None:
        return MAGENTA
    h, _, s = colorsys.rgb_to_hls(*(c / 255 for c in rgb))
    hue = h * 360
    if s >= 0.2 and (hue >= 260 or hue <= 15):
        return GREEN
    return MAGENTA


def folded_prompt(backdrop: Backdrop, category: str | None = None) -> str:
    """Folded for clothes, each kind into its own shape (_SHAPES); arranged
    as they are for shoes (as the pair, on their sides), bags and
    accessories — squared up with the frame, seen from above. Lit from one
    side so it reads in 3D (shading across the folds and the fabric's
    thickness) — but nothing cast on the backdrop,
    which is keyed out."""
    if category == "shoes":
        lead = LAID_OUT_PROMPT + _PAIR
    elif category in UNFOLDABLE:
        lead = LAID_OUT_PROMPT + _LAY
    else:
        lead = FOLDED_PROMPT + _SHAPES.get(category or "", _FOLD)
    return (
        f"{lead}, alone on a flat, evenly coloured, solid pure "
        f"{backdrop.name} ({backdrop.hex}) background that fills the whole "
        f"frame. {_SQUARE} Soft studio light from the upper left gives it natural "
        "depth: gentle shading across the folds and edges shows its "
        "thickness and texture in 3D. No shadow on the background, no "
        "surface texture, no props, no text."
    )


async def make_cutout(
    photo: bytes,
    *,
    media_type: str,
    color_hex: str | None,
    garment_images: GarmentImageProvider,
    remover: BackgroundRemover,
    category: str | None = None,
) -> Cutout | None:
    """The piece in [photo], folded, keyed out and placed on the canvas — or
    None when the model or the key fails (logged; the piece just has no
    cut-out)."""
    backdrop = pick_backdrop(color_hex)
    for attempt in range(1, KEY_ATTEMPTS + 1):
        try:
            shot = await garment_images.generate(
                photo,
                media_type=media_type,
                prompt=folded_prompt(backdrop, category),
            )
            image = Image.open(io.BytesIO(shot.content))
            image.load()
            keyed = remover.remove(image, backdrop=backdrop.rgb)
            return place_on_canvas(keyed)
        except GarmentImageError as e:
            # Rate limits are already retried by the provider.
            _log.warning("cutout.generate_failed", code=e.code, error=str(e))
            return None
        except BackgroundRemovalError as e:
            # The model drew a backdrop that won't key (uneven, wrong
            # colour): a fresh drawing usually comes out right.
            _log.warning(
                "cutout.key_failed",
                code=e.code,
                backdrop=backdrop.name,
                attempt=attempt,
            )
        except (OSError, ValueError) as e:  # not an image Pillow can read
            _log.warning("cutout.unreadable", error=str(e), attempt=attempt)
    return None


def place_on_canvas(rgba: Image.Image) -> Cutout:
    """Trims [rgba] to the piece and centres it, scaled to fit inside the
    margin, on the transparent CANVAS square. Raises BackgroundRemovalError
    if nothing is opaque."""
    rgba = _drop_specks(rgba)
    alpha = rgba.getchannel("A").point(lambda a: 255 if a > ALPHA_FLOOR else 0)
    bbox = alpha.getbbox()
    if bbox is None:
        raise BackgroundRemovalError("no_subject", "Nothing left after keying.")
    piece = rgba.crop(bbox)

    room = CANVAS * (1 - 2 * MARGIN)
    scale = room / max(piece.width, piece.height)
    size = (max(1, round(piece.width * scale)), max(1, round(piece.height * scale)))
    piece = piece.resize(size, Image.Resampling.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    x = (CANVAS - size[0]) // 2
    y = (CANVAS - size[1]) // 2
    canvas.alpha_composite(piece, (x, y))

    out = io.BytesIO()
    canvas.save(out, format="WEBP", quality=90, alpha_quality=100, method=4)
    box = tuple(round(v / CANVAS, 4) for v in (x, y, size[0], size[1]))
    return Cutout(content=out.getvalue(), content_type=CONTENT_TYPE, box=box)  # type: ignore[arg-type]


def _drop_specks(rgba: Image.Image) -> Image.Image:
    """[rgba] with stray specks the key left behind cleared: blobs (found
    on a coarse grid, so a gap of a few pixels still separates them) under
    SPECK_SHARE of the biggest one. Otherwise a speck far from the piece
    stretches its box, and the app draws the piece too small. Parts of the
    piece that stand apart (two shoes, a strap) are far bigger and stay."""
    a = np.asarray(rgba.getchannel("A")) > ALPHA_FLOOR
    h, w = a.shape
    cell = max(1, -(-max(h, w) // SPECK_GRID))
    gh, gw = -(-h // cell), -(-w // cell)
    padded = np.zeros((gh * cell, gw * cell), dtype=bool)
    padded[:h, :w] = a
    counts = padded.reshape(gh, cell, gw, cell).sum(axis=(1, 3))

    # Label the occupied cells, 8-connected.
    labels = np.zeros((gh, gw), dtype=np.int32)
    sizes = [0]
    for start in zip(*np.nonzero(counts)):
        if labels[start]:
            continue
        label = len(sizes)
        labels[start] = label
        stack, size = [start], 0
        while stack:
            y, x = stack.pop()
            size += int(counts[y, x])
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if (
                        0 <= ny < gh
                        and 0 <= nx < gw
                        and counts[ny, nx]
                        and not labels[ny, nx]
                    ):
                        labels[ny, nx] = label
                        stack.append((ny, nx))
        sizes.append(size)
    if len(sizes) <= 2:  # nothing, or one blob
        return rgba

    keep = np.array(sizes) >= max(sizes) * SPECK_SHARE
    keep[0] = False
    fine = np.repeat(np.repeat(keep[labels], cell, axis=0), cell, axis=1)[:h, :w]
    out = np.array(rgba)
    out[..., 3] = np.where(fine, out[..., 3], 0)
    return Image.fromarray(out, "RGBA")


def _parse_hex(value: str | None) -> tuple[int, int, int] | None:
    if not value:
        return None
    v = value.strip().lstrip("#")
    if len(v) != 6:
        return None
    try:
        return (int(v[0:2], 16), int(v[2:4], 16), int(v[4:6], 16))
    except ValueError:
        return None
