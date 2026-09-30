"""Scan accuracy report — how often users correct the vision model's answer.

Prints, per model, how many scanned items there are and the share of each
field (category / color / pattern / formality) the user kept as the AI said
it. Use it to decide whether the cheap vision model (AI_VISION_MODEL) is
accurate enough, or to compare two models after switching.

Run from backend/ with the venv active (reads the same .env as the app):

    python scripts/scan_accuracy_report.py
    python scripts/scan_accuracy_report.py --days 30   # only recent scans

tbd: run on the box as the zoura user from /opt/zoura/app.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.session import SessionLocal  # noqa: E402
from app.services.scan_accuracy_service import FIELDS, scan_accuracy  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--days", type=int, help="only items scanned in the last N days")
    args = parser.parse_args()
    since = datetime.now(timezone.utc) - timedelta(days=args.days) if args.days else None

    with SessionLocal() as db:
        rows = scan_accuracy(db, since=since)
    if not rows:
        print("No scanned items yet.")
        return

    header = f"{'model':<28}{'items':>7}{'untouched':>11}" + "".join(
        f"{key:>11}" for key in FIELDS
    )
    print(header)
    print("-" * len(header))
    for acc in rows:
        untouched = 1 - acc.any_corrected / acc.items
        print(
            f"{acc.model:<28}{acc.items:>7}{untouched:>11.0%}"
            + "".join(f"{acc.accuracy(key):>11.0%}" for key in FIELDS)
        )
    print("\nPercentages = share of items where the user kept the AI's value.")


if __name__ == "__main__":
    main()
