"""Dev tool: queues a cut-out for every wardrobe item that has a photo but no
cut-out (and none queued), for the image worker to make.

    python scripts/fill_missing_cutouts.py [--email dev@example.com] [--run]

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
    queued = 0
    for item in db.scalars(query).all():
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
