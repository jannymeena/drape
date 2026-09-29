"""Wipe all rows in the dev DB and reseed from scratch.

Usage (from backend/, with the venv active):

    python scripts/reset_dev_db.py

What it does:
    1. TRUNCATE every app table (CASCADE follows FKs; RESTART IDENTITY resets sequences).
    2. Idempotently create the dev user (delegates to seed_dev_user.main()).

The product catalog is wiped too; the catalog worker re-syncs and re-tags it on
the next server start.

What it preserves:
    - Schema (tables, columns, indexes, FKs).
    - Postgres enum types (`user_role`, `auth_method`).
    - The `alembic_version` row, so Alembic still knows which migration is applied.

Refuses to run when ENVIRONMENT != dev — never wipe a tbd/prd database.
"""
from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import create_engine, text  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.base import Base  # noqa: E402
import app.db.models  # noqa: E402,F401  -- register models with metadata
from scripts import seed_dev_user  # noqa: E402



def _truncate_all(engine) -> int:
    tables = [t.name for t in Base.metadata.sorted_tables if t.name != "alembic_version"]
    if not tables:
        return 0
    quoted = ", ".join(f'"{name}"' for name in tables)
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE TABLE {quoted} RESTART IDENTITY CASCADE"))
    return len(tables)


def main() -> int:
    if settings.environment != "dev":
        print(
            f"refusing to reset: ENVIRONMENT={settings.environment!r} (only 'dev' is allowed)",
            file=sys.stderr,
        )
        return 2

    engine = create_engine(settings.database_url)
    truncated = _truncate_all(engine)
    print(f"truncated {truncated} tables")

    print()
    print("=== seeding dev user ===")
    seed_dev_user.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
