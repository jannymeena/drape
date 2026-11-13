"""Cut-outs: backdrop choice, the square canvas, and the generate → key path."""

from __future__ import annotations

import io

import pytest
from PIL import Image, ImageDraw

from app.services.cutout_service import (
    CANVAS,
    GREEN,
    MAGENTA,
    MARGIN,
    folded_prompt,
    make_cutout,
    pick_backdrop,
    place_on_canvas,
)
from app.services.providers.background_removal.chroma_key import ChromaKeyRemover
from app.services.providers.garment_image.base import (
    GarmentImageError,
    GarmentImageProvider,
    GeneratedImage,
)


@pytest.mark.parametrize(
    "color_hex, expected",
    [
        (None, MAGENTA),
        ("not-a-colour", MAGENTA),
        ("#1E2A50", MAGENTA),  # navy
        ("#2E7D32", MAGENTA),  # green piece: magenta is far away
        ("#D2B48C", MAGENTA),  # tan
        ("#808080", MAGENTA),  # grey (no hue)
        ("#F4A6C0", GREEN),  # pink
        ("#7B3FA0", GREEN),  # purple
        ("#C2185B", GREEN),  # magenta-ish
        ("#D32F2F", GREEN),  # red, close to the magenta key
    ],
)
def test_backdrop_steers_clear_of_the_piece_colour(color_hex, expected):
    assert pick_backdrop(color_hex) == expected


def test_prompt_is_the_fold_plus_the_backdrop():
    p = folded_prompt(MAGENTA)
    assert p.startswith("Show this exact garment neatly folded")
    assert "magenta (#FF00FF)" in p
    assert "No shadow" in p


def _rgba_piece(w: int, h: int, *, at=(30, 50), size=(400, 300)) -> Image.Image:
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    x, y = at
    ImageDraw.Draw(img).rectangle(
        [x, y, x + size[0] - 1, y + size[1] - 1], fill=(20, 30, 80, 255)
    )
    return img


def _decode(content: bytes) -> Image.Image:
    img = Image.open(io.BytesIO(content))
    img.load()
    return img


def test_canvas_is_square_transparent_and_the_piece_centred():
    cut = place_on_canvas(_rgba_piece(800, 600))
    img = _decode(cut.content)

    assert cut.content_type == "image/webp"
    assert img.size == (CANVAS, CANVAS) and img.mode == "RGBA"
    assert img.getpixel((2, 2))[3] == 0  # transparent margin

    x, y, w, h = cut.box
    # The longer side fills the room inside the margin; centred both ways.
    assert w == pytest.approx(1 - 2 * MARGIN, abs=0.002)
    assert h == pytest.approx(w * 300 / 400, abs=0.002)
    assert x == pytest.approx(MARGIN, abs=0.002)
    assert y + h / 2 == pytest.approx(0.5, abs=0.002)


def test_a_tall_piece_fills_the_height():
    x, y, w, h = place_on_canvas(_rgba_piece(500, 900, size=(200, 600))).box
    assert h == pytest.approx(1 - 2 * MARGIN, abs=0.002)
    assert x + w / 2 == pytest.approx(0.5, abs=0.002)


def _png(image: Image.Image) -> bytes:
    out = io.BytesIO()
    image.save(out, format="PNG")
    return out.getvalue()


class _Folds(GarmentImageProvider):
    """Draws the 'folded' piece: a navy block on whatever backdrop the
    prompt asks for."""

    def __init__(self, *, fail: bool = False, backdrop=None) -> None:
        self.prompts: list[str] = []
        self.fail = fail
        self.backdrop = backdrop

    async def generate(self, image_bytes, *, media_type, prompt):
        self.prompts.append(prompt)
        if self.fail:
            raise GarmentImageError("no_image", "refused")
        colour = self.backdrop or (GREEN.rgb if "green" in prompt else MAGENTA.rgb)
        img = Image.new("RGB", (600, 600), colour)
        ImageDraw.Draw(img).rectangle([150, 200, 450, 420], fill=(20, 30, 80))
        return GeneratedImage(content=_png(img), content_type="image/png")


async def _make(folds, color_hex=None):
    return await make_cutout(
        b"photo",
        media_type="image/jpeg",
        color_hex=color_hex,
        garment_images=folds,
        remover=ChromaKeyRemover(),
    )


async def test_photo_becomes_a_cut_out():
    folds = _Folds()
    cut = await _make(folds)

    assert cut is not None
    assert folds.prompts == [folded_prompt(MAGENTA)]
    img = _decode(cut.content)
    assert img.getpixel((5, 5))[3] == 0
    assert img.getpixel((CANVAS // 2, CANVAS // 2))[3] == 255


async def test_a_pink_piece_is_drawn_on_green():
    folds = _Folds()
    assert await _make(folds, color_hex="#F4A6C0") is not None
    assert folds.prompts == [folded_prompt(GREEN)]


async def test_a_refused_generation_means_no_cut_out():
    assert await _make(_Folds(fail=True)) is None


async def test_a_backdrop_that_cant_be_keyed_means_no_cut_out():
    # The model ignored the backdrop and drew on white.
    assert await _make(_Folds(backdrop=(255, 255, 255))) is None


async def test_an_unreadable_image_means_no_cut_out():
    class _Junk(_Folds):
        async def generate(self, image_bytes, *, media_type, prompt):
            return GeneratedImage(content=b"not an image", content_type="image/png")

    assert await _make(_Junk()) is None

