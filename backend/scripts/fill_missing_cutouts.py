"""Dev tool: makes the cut-out for every wardrobe item that has a photo but
no cut-out (an upload that hit Google's rate limit, or a backdrop that
wouldn't key), one at a time and paced, then puts it on the outfits that
hold the item.

    python scripts/fill_missing_cutouts.py [--email dev@example.com] [--dry-run]

The source photo is the item's last image — the user's own photo (a
mannequin shot, when there is one, goes before it).
"""

from __future__ import annotations

import argparse
import asyncio
import mimetypes
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import httpx  # noqa: E402
from sqlalchemy import select  # noqa: E402

from app.core.providers import providers  # noqa: E402
from app.db.models import User, WardrobeItem  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.services import cutout_service, wardrobe_service  # noqa: E402

# Between items, to stay under Google's per-minute quota.
_PACE_S = 8.0


async def _photo(url: str) -> tuple[bytes, str]:
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.get(url)
        resp.raise_for_status()
    media_type = resp.headers.get("content-type") or (
        mimetypes.guess_type(url)[0] or "image/jpeg"
    )
    return resp.content, media_type.split(";")[0]


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", help="only this user's items")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if not providers.garment_images.enabled:
        sys.exit("No image model configured (GOOGLE_AI_API_KEY).")

    db = SessionLocal()
    query = select(WardrobeItem).where(
        WardrobeItem.cutout_url.is_(None),
        WardrobeItem.is_starter_wardrobe.is_(False),
    )
    if args.email:
        query = query.join(User, User.id == WardrobeItem.user_id).where(
            User.email == args.email
        )
    items = [i for i in db.scalars(query).all() if i.images]
    print(f"{len(items)} item(s) without a cut-out")

    made = 0
    for n, item in enumerate(items, 1):
        print(f"[{n}/{len(items)}] {item.name} ({item.category})", end=" … ")
        if args.dry_run:
            print("skipped (dry run)")
            continue
        try:
            photo, media_type = await _photo(item.images[-1])
        except httpx.HTTPError as e:
            print(f"photo unreadable: {e}")
            continue
        cut = await cutout_service.make_cutout(
            photo,
            media_type=media_type,
            color_hex=item.color_hex,
            category=item.category,
            garment_images=providers.garment_images,
            remover=providers.background_remover,
        )
        if cut is None:
            print("failed (see the log)")
        else:
            wardrobe_service.save_cutout(
                db, item=item, cut=cut, storage=providers.image_storage
            )
            made += 1
            print("done")
        if n < len(items):
            await asyncio.sleep(_PACE_S)
    print(f"{made} cut-out(s) made")


if __name__ == "__main__":
    asyncio.run(main())
