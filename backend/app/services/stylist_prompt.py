"""The personal-stylist brief shared by outfit generation and the AI advisor.

`STYLIST_EXPERTISE` is how Zoura styles: the judgement a good personal stylist
brings (a dress is a complete base, footwear sets the tone, dressing for body
shape, colouring and age, the season). `about_the_user` renders everything the
user told us about themselves. Both are stable per user, so callers put them
in the cacheable system prefix.
"""
from __future__ import annotations

from typing import Optional

from app.services import fit_profile as fit_profile_mod

STYLIST_EXPERTISE = (
    "How you style. These are the principles a good personal stylist works "
    "from; apply them with judgement rather than as a checklist:\n"
    "- Build around one anchor piece. A dress or jumpsuit is a complete base: "
    "finish it with shoes and, if the weather or look calls for it, a layer "
    "(jacket, cardigan, coat) and accessories. Never put trousers, jeans or a "
    "skirt with a dress. Separates need both a top and a bottom.\n"
    "- Footwear sets the tone. Boots with a dress is a go-to (ankle boots with "
    "midi and mini dresses, knee-high boots when it's cold); trainers or loafers "
    "dress a look down, heels or sleek flats dress it up. Match the shoe's "
    "weight to the outfit's.\n"
    "- Dress the body in front of you. Use the wearer's body shape and fit "
    "preferences: balance proportions (structure on the shoulders to balance "
    "fuller hips, define the waist on an hourglass, create one on a straighter "
    "frame with a belt or wrap), and lengthen with a tonal column, a V-neck or "
    "shoes in a similar tone to the legs or trousers. Flatter, never lecture.\n"
    "- Colour: favour shades that suit the wearer's undertone and the palettes "
    "they like. Keep to two or three colours, let a neutral carry a statement "
    "piece, and repeat a colour to tie the look together.\n"
    "- Age: style for the wearer's age range with a modern eye. Clean fit, one "
    "current silhouette, updated footwear and fresh accessories keep a look "
    "youthful; avoid what reads dated (head-to-toe matching sets, tired "
    "silhouettes) and what tries too hard to look young. Never mention age in "
    "what you write; talk about looking fresh, polished and current.\n"
    "- Be current. Use today's date for the season and bring in what's "
    "fashionable now when it suits the wearer and the pieces available, but "
    "never at the expense of fit or the occasion. Don't claim specific trends "
    "you aren't sure of; timeless styling beats a guessed trend.\n"
    "- Respect the occasion, the dress code and the impression the wearer "
    "wants to make, and dress for the weather: layers and closed shoes when "
    "it's cold or wet, breathable fabrics and fewer layers when it's hot.\n"
    "- Be a stylist, not a sorting machine: when a less obvious pairing is "
    "better (a dress with boots, a blazer over a tee), choose it over the "
    "predictable one.\n"
)


def build_wearer_block(body_analysis: Optional[dict]) -> str:
    """A short 'Wearer:' line from the avatar-derived body/skin blob (§5.5), so
    suggestions account for the person's body type and colouring. Empty when no
    analysis exists (avatar not uploaded / analysis failed)."""
    if not body_analysis:
        return ""
    bits = []
    if body_analysis.get("body_type"):
        bits.append(f"body type {body_analysis['body_type']}")
    if body_analysis.get("skin_tone"):
        bits.append(f"skin tone {body_analysis['skin_tone']}")
    notes = body_analysis.get("styling_notes")
    if not bits and not notes:
        return ""
    head = f"Wearer: {', '.join(bits)}." if bits else "Wearer notes:"
    tail = f" {notes}" if notes else ""
    return f"{head}{tail} Favor fits and colours that flatter this.\n"


def about_the_user(
    *,
    shopping_style: Optional[str] = None,
    age_range: Optional[str] = None,
    style_goals: Optional[list[str]] = None,
    style_profile: Optional[dict] = None,
    body_analysis: Optional[dict] = None,
    fit: Optional[dict] = None,
) -> str:
    """Who the stylist is dressing: shopping style, age range, goals, the
    style-blueprint answers (occupation left out), the avatar analysis and
    the consent-gated fit summary (§5.5.1; `None` unless the user opted in).
    One fact per line, ending in a newline."""
    lines = [
        "Shops for: "
        + {"womens": "womenswear", "mens": "menswear"}.get(
            shopping_style or "", "womenswear and menswear"
        )
        + "."
    ]
    if age_range and age_range != "prefer_not_to_say":
        lines.append(f"Age range: {age_range}.")
    lines.append(
        f"Style goals: {', '.join(style_goals)}." if style_goals else "Style goals: none."
    )
    for key, value in sorted((style_profile or {}).items()):
        if key == "occupation" or value in (None, "", []):
            continue
        shown = ", ".join(map(str, value)) if isinstance(value, list) else value
        lines.append(f"{key.replace('_', ' ')}: {shown}.")
    return (
        "\n".join(lines)
        + "\n"
        + build_wearer_block(body_analysis)
        + fit_profile_mod.to_prompt_block(fit)
    )
