"""Orphaned-image GC (§3.1 hardening).

Uploads happen before the DB row that references them (wardrobe item images,
avatar), so a crashed request, an abandoned upload, or a deleted row can leave
objects in storage that nothing references. This walks the image store,
subtracts every URL the DB still points at, and removes what's left.

Safety rails:
  * dry-run by default — pass --delete to actually remove anything;
  * objects younger than --min-age-hours (default 24) are never touched, so
    an upload racing this script can't be collected before its row commits.

Run from backend/ with the venv active (reads the same .env as the app):

    python scripts/gc_orphaned_images.py            # report only
    python scripts/gc_orphaned_images.py --delete   # actually collect

tbd: run on the box as the zoura user from /opt/zoura/app; wire into cron
alongside the nightly pg_dump if churn ever warrants it.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import select  # noqa: E402

from app.core.providers import providers  # noqa: E402
from app.db.models import Outfit, Profile, WardrobeItem  # noqa: E402
from app.db.session import SessionLocal  # noqa: E402


def referenced_urls(db) -> set[str]:
    """Every image URL the DB currently points at, across all owners."""
    urls: set[str] = set()
    for (url,) in db.execute(
        select(Profile.avatar_url).where(Profile.avatar_url.is_not(None))
    ):
        urls.add(url)
    for images, primary in db.execute(
        select(WardrobeItem.images, WardrobeItem.primary_image_url)
    ):
        urls.update(images or [])
        if primary:
            urls.add(primary)
    for image_url, items in db.execute(select(Outfit.image_url, Outfit.items)):
        if image_url:
            urls.add(image_url)
        # Outfit item payloads embed copies of wardrobe image URLs; treat any
        # url-valued field as a live reference rather than relying on the
        # wardrobe row still existing.
        for item in items or []:
            for value in item.values():
                if isinstance(value, str) and value.startswith(("http://", "https://")):
                    urls.add(value)
    return urls


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--delete", action="store_true", help="actually delete (default: dry-run report)"
    )
    parser.add_argument(
        "--min-age-hours",
        type=float,
        default=24.0,
        help="never touch objects newer than this (default 24h)",
    )
    args = parser.parse_args()

    storage = providers.image_storage
    cutoff = datetime.now(timezone.utc) - timedelta(hours=args.min_age_hours)

    with SessionLocal() as db:
        live = referenced_urls(db)

    total = orphans = skipped_young = 0
    for url, modified in storage.list_all():
        total += 1
        if url in live:
            continue
        if modified > cutoff:
            skipped_young += 1
            continue
        orphans += 1
        if args.delete:
            storage.delete(url=url)
            print(f"deleted  {url}")
        else:
            print(f"orphan   {url}  (modified {modified.isoformat()})")

    mode = "deleted" if args.delete else "found (dry-run; pass --delete to remove)"
    print(
        f"\n{total} objects scanned · {len(live)} referenced · "
        f"{skipped_young} skipped (younger than {args.min_age_hours:g}h) · "
        f"{orphans} orphans {mode}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
