"""Dev tool: queues a cut-out for every wardrobe item that has a photo but no
cut-out (and none queued), for the image worker to make.

    python scripts/fill_missing_cutouts.py [--email dev@example.com] [--category tops ...] [--redo] [--run]

`--redo` remakes the items' existing cut-outs too (after the cut-out prompt
changes): it drops each one's cut-out and queues a new one. Saved outfits
keep showing the old one until the new one lands.

The running API's image worker picks the jobs up by itself. `--run` works
through the queue here instead (when the server isn't running), one job at
a time and paced, until nothing is due.
"""

from __future__ import annotations

import argparse
import asyncio
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select  # noqa: E402

from app.core.providers import providers  # noqa: E402
from app.db.models import User, WardrobeItem  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402
from app.services import image_job_service  # noqa: E402
from app.workers.image_worker import PACE_S, ImageWorker  # noqa: E402


async def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--email", help="only this user's items")
    parser.add_argument("--run", action="store_true", help="work the queue here")
    parser.add_argument(
        "--redo", action="store_true", help="remake existing cut-outs too"
    )
    parser.add_argument(
        "--category", action="append", help="only these categories (repeatable)"
    )
    args = parser.parse_args()

    if not providers.garment_images.enabled:
        sys.exit("No image model configured (GOOGLE_AI_API_KEY).")

    db = SessionLocal()
    query = select(WardrobeItem).where(
        WardrobeItem.is_starter_wardrobe.is_(False),
    )
    if not args.redo:
        query = query.where(WardrobeItem.cutout_url.is_(None))
    if args.category:
        query = query.where(WardrobeItem.category.in_(args.category))
    if args.email:
        query = query.join(User, User.id == WardrobeItem.user_id).where(
            User.email == args.email
        )
    queued = 0
    for item in db.scalars(query).all():
        if args.redo and item.cutout_url:
            item.cutout_url = None
            item.cutout_box = None
            db.commit()
        if image_job_service.enqueue_cutout(db, item=item):
            queued += 1
            print(f"queued: {item.name} ({item.category})")
    db.close()
    print(f"{queued} cut-out(s) queued")

    if args.run:
        worker = ImageWorker(
            session_factory=SessionLocal,
            storage=providers.image_storage,
            garment_images=providers.garment_images,
            remover=providers.background_remover,
        )
        done = 0
        while await worker.run_once():
            done += 1
            print(f"worked {done} job(s)")
            await asyncio.sleep(PACE_S)
        print("nothing more due (retries, if any, are scheduled for later)")


if __name__ == "__main__":
    asyncio.run(main())
