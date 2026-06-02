# Drape backend — container image for the AWS test deploy (App Runner).
#
# Build for App Runner's amd64 runtime (REQUIRED on Apple Silicon):
#   docker build --platform linux/amd64 -t drape-backend .
#
# The image ships NO secrets. Config comes from runtime env vars (App Runner
# RuntimeEnvironmentVariables) which pydantic-settings reads from os.environ —
# they take precedence over any .env file, and .env is .dockerignore'd anyway.
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Dependencies first for layer caching. psycopg2-binary / cryptography ship
# manylinux wheels, so no compiler/system libs are needed on slim.
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Application source + migrations. `data/` is required: the init migration
# (6b13316bc906) seeds starter_wardrobe_templates from
# data/starter_wardrobe_templates.json during `alembic upgrade head`.
COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./alembic.ini
COPY data ./data
COPY entrypoint.sh ./entrypoint.sh

# LocalFsStorage (ENVIRONMENT=dev) writes uploads here and FastAPI serves them
# back at LOCAL_IMAGE_BASE_URL. Ephemeral on App Runner — fine for a test rig.
RUN chmod +x ./entrypoint.sh \
    && mkdir -p /app/uploads \
    && useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000
ENTRYPOINT ["./entrypoint.sh"]
