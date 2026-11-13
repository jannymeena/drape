"""Colour-key background removal on synthetic images."""

from __future__ import annotations

import numpy as np
import pytest
from PIL import Image, ImageDraw

from app.services.providers.background_removal.base import BackgroundRemovalError
from app.services.providers.background_removal.chroma_key import ChromaKeyRemover

MAGENTA = (255, 0, 255)
GREEN = (0, 255, 0)
NAVY = (20, 30, 80)
PINK = (240, 150, 180)


def _piece_on(backdrop, colour, *, size=200, box=(50, 60, 150, 140)) -> Image.Image:
    """A [colour] ellipse on [backdrop], drawn at 4× and scaled down so its
    edge is a soft blend of the two — like a real render."""
    big = Image.new("RGB", (size * 4, size * 4), backdrop)
    ImageDraw.Draw(big).ellipse([v * 4 for v in box], fill=colour)
    return big.resize((size, size), Image.Resampling.LANCZOS)


def _rgba(image: Image.Image) -> np.ndarray:
    return np.asarray(image, dtype=np.float32)


def test_backdrop_goes_clear_and_the_piece_stays_solid():
    out = ChromaKeyRemover().remove(_piece_on(MAGENTA, NAVY), backdrop=MAGENTA)
    px = _rgba(out)

    assert out.mode == "RGBA" and out.size == (200, 200)
    assert px[5, 5, 3] == 0  # corner: backdrop
    assert px[100, 100, 3] == 255  # centre: the piece
    assert np.allclose(px[100, 100, :3], NAVY, atol=2)


def test_soft_edges_keep_the_piece_colour_not_a_pink_fringe():
    px = _rgba(ChromaKeyRemover().remove(_piece_on(MAGENTA, NAVY), backdrop=MAGENTA))
    edge = (px[..., 3] > 0) & (px[..., 3] < 255)

    assert edge.sum() > 20  # there is a soft edge
    colours = px[edge][:, :3]
    # Unmixed back to (about) navy: no red/blue cast from the backdrop.
    assert np.abs(colours - NAVY).max() < 40


def test_a_backdrop_off_the_exact_hex_is_still_keyed():
    rendered = (235, 25, 228)  # the model's idea of "pure magenta"
    px = _rgba(ChromaKeyRemover().remove(_piece_on(rendered, NAVY), backdrop=MAGENTA))
    assert px[5, 5, 3] == 0
    assert px[100, 100, 3] == 255


def test_a_drop_shadow_on_the_backdrop_goes_too():
    # The model's soft shadow: a darker magenta down and right of the piece.
    img = Image.new("RGB", (800, 800), MAGENTA)
    draw = ImageDraw.Draw(img)
    draw.ellipse([220, 260, 640, 600], fill=(170, 0, 170))  # shadow
    draw.ellipse([200, 240, 600, 560], fill=(240, 232, 215))  # cream piece
    img = img.resize((200, 200), Image.Resampling.LANCZOS)

    px = _rgba(ChromaKeyRemover().remove(img, backdrop=MAGENTA))
    shadow_only = (152, 145)  # in the shadow, off the piece
    assert px[shadow_only[1], shadow_only[0], 3] == 0
    # Edge pixels stay cream — no pink halo.
    edge = (px[..., 3] > 0) & (px[..., 3] < 255)
    colours = px[edge][:, :3]
    assert np.abs(colours - (240, 232, 215)).max() < 40


@pytest.mark.parametrize("colour", [(15, 15, 15), (20, 30, 80), (110, 110, 110)])
def test_dark_pieces_are_not_mistaken_for_shadow(colour):
    px = _rgba(ChromaKeyRemover().remove(_piece_on(MAGENTA, colour), backdrop=MAGENTA))
    assert px[100, 100, 3] == 255


def test_pink_piece_on_green():
    px = _rgba(ChromaKeyRemover().remove(_piece_on(GREEN, PINK), backdrop=GREEN))
    assert px[5, 5, 3] == 0
    assert np.allclose(px[100, 100, :3], PINK, atol=2)
    assert px[100, 100, 3] == 255


@pytest.mark.parametrize(
    "image, code",
    [
        # Half the frame isn't backdrop.
        (
            Image.fromarray(
                np.concatenate(
                    [
                        np.full((200, 100, 3), MAGENTA, np.uint8),
                        np.full((200, 100, 3), 255, np.uint8),
                    ],
                    axis=1,
                )
            ),
            "uneven_backdrop",
        ),
        # A white backdrop when magenta was asked for.
        (_piece_on((255, 255, 255), NAVY), "wrong_backdrop"),
        # Nothing on it.
        (Image.new("RGB", (200, 200), MAGENTA), "no_subject"),
    ],
)
def test_refuses_what_it_cant_key(image, code):
    with pytest.raises(BackgroundRemovalError) as e:
        ChromaKeyRemover().remove(image, backdrop=MAGENTA)
    assert e.value.code == code
