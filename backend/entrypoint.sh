#!/bin/sh
# Container entrypoint: apply migrations, then serve.
#
# `alembic upgrade head` is idempotent and, on a fresh DB, both creates the full
# schema and seeds starter_wardrobe_templates (see migration 6b13316bc906). It
# targets DATABASE_URL because alembic/env.py overrides the URL with
# settings.database_url. Single-instance test rig, so running it on start is
# fine; a multi-instance prod deploy would run migrations as a one-shot instead.
set -eu

echo "[entrypoint] alembic upgrade head"
alembic upgrade head

echo "[entrypoint] starting uvicorn on 0.0.0.0:8000"
exec uvicorn app.main:app --host 0.0.0.0 --port 8000
