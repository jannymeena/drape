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

# The fold itself; the backdrop line is added per piece.
FOLDED_PROMPT = "Show this exact garment neatly folded"

# Things that don't fold (a folded trainer comes out crumpled) are laid out
# as they are instead.
LAID_OUT_PROMPT = "Show this exact item neatly arranged, seen from above"
UNFOLDABLE = frozenset({"shoes", "bags", "jewelry", "accessories"})

# Side of the square canvas every cut-out is placed on, and the empty margin
# around the piece (each side, as a share of the side).
CANVAS = 1024
MARGIN = 0.04

CONTENT_TYPE = "image/webp"

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
    """Folded for clothes; arranged as they are for shoes, bags and
    accessories. Lit from one side so it reads in 3D (shading across the
    folds and the fabric's thickness) — but nothing cast on the backdrop,
    which is keyed out."""
    lead = LAID_OUT_PROMPT if category in UNFOLDABLE else FOLDED_PROMPT
    return (
        f"{lead}, alone on a flat, evenly coloured, solid pure "
        f"{backdrop.name} ({backdrop.hex}) background that fills the whole "
        "frame. Soft studio light from the upper left gives it natural "
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
    alpha = rgba.getchannel("A").point(lambda a: 255 if a > 25 else 0)
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
