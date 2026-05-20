"""Wipe all rows in the dev DB and reseed from scratch.

Usage (from backend/, with the venv active):

    python scripts/reset_dev_db.py

What it does:
    1. TRUNCATE every app table (CASCADE follows FKs; RESTART IDENTITY resets sequences).
    2. Re-seed `starter_wardrobe_templates` from data/starter_wardrobe_templates.json
       (the migration seeds them on `alembic upgrade head`, but TRUNCATE wipes them).
    3. Idempotently create the dev user (delegates to seed_dev_user.main()).

What it preserves:
    - Schema (tables, columns, indexes, FKs).
    - Postgres enum types (`user_role`, `auth_method`).
    - The `alembic_version` row, so Alembic still knows which migration is applied.

Refuses to run when ENVIRONMENT != dev — never wipe a tbd/prd database.
"""
from __future__ import annotations

import json
import sys
import uuid
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from sqlalchemy import create_engine, text  # noqa: E402

from app.core.config import settings  # noqa: E402
from app.db.base import Base  # noqa: E402
import app.db.models  # noqa: E402,F401  -- register models with metadata
from scripts import seed_dev_user  # noqa: E402


_TEMPLATES_JSON = Path(__file__).resolve().parent.parent / "data" / "starter_wardrobe_templates.json"


def _truncate_all(engine) -> int:
    tables = [t.name for t in Base.metadata.sorted_tables if t.name != "alembic_version"]
    if not tables:
        return 0
    quoted = ", ".join(f'"{name}"' for name in tables)
    with engine.begin() as conn:
        conn.execute(text(f"TRUNCATE TABLE {quoted} RESTART IDENTITY CASCADE"))
    return len(tables)


def _reseed_starter_wardrobe_templates(engine) -> int:
    templates = json.loads(_TEMPLATES_JSON.read_text())
    rows = [
        {
            "id": str(uuid.uuid4()),
            "template_id": t["template_id"],
            "name": t["name"],
            "gender": t.get("gender"),
            "age_range": t.get("age_range"),
            "style_profile": t.get("style_profile"),
            "total_items": len(t["items"]),
            "items": json.dumps(t["items"]),
        }
        for t in templates
    ]
    with engine.begin() as conn:
        conn.execute(
            text(
                """
                INSERT INTO starter_wardrobe_templates
                    (id, template_id, name, gender, age_range, style_profile,
                     total_items, items)
                VALUES
                    (:id, :template_id, :name, :gender, :age_range, :style_profile,
                     :total_items, CAST(:items AS jsonb))
                """
            ),
            rows,
        )
    return len(rows)


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

    seeded = _reseed_starter_wardrobe_templates(engine)
    print(f"reseeded {seeded} starter wardrobe templates")

    print()
    print("=== seeding dev user ===")
    seed_dev_user.main()
    return 0


if __name__ == "__main__":
    sys.exit(main())
