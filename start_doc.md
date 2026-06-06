# Drape Backend — Local Dev Runbook

Quick reference for starting, stopping, and resetting the dev backend. For phase-level build details see [`PROJECT_STATUS.md`](./PROJECT_STATUS.md); for forward-looking work see [`PROJECT_STATUS.md`](./PROJECT_STATUS.md).

---

## Prerequisites

- **Python venv** at `<project_dir>/drape/.venv` with deps from `backend/requirements.txt` installed.
- **Postgres on port 5433** (the docker-compose container). If you get connection errors, start it:
  ```bash
  cd <project_dir>/drape && docker compose up -d
  ```
- **`.env`** in `backend/` with at minimum `MEASUREMENT_DEK_DEV` set. (Generate with `python -c 'import os, base64; print(base64.b64encode(os.urandom(32)).decode())'`.)

---

## Start the server

```bash
cd <project_dir>/drape && 
source .venv/bin/activate && 
cd backend && 
uvicorn app.main:app --reload
```

**What each part does:**
- `cd <project_dir>/drape` — repo root
- `source .venv/bin/activate` — activate the Python venv (FastAPI, SQLAlchemy, etc.)
- `cd backend` — uvicorn needs to run from here so `app.main` resolves and `.env` loads
- `uvicorn app.main:app --reload` — ASGI server on port 8000 with auto-reload on file changes

**Once it's up:**
- API: http://localhost:8000
- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc
- Health check: http://localhost:8000/api/v1/health

**To stop:** `Ctrl+C` in the terminal.

---

## Get a bearer token for Swagger

```bash
cd <project_dir>/drape && 
source .venv/bin/activate && 
cd backend && 
python scripts/seed_dev_user.py
```

Idempotently creates `dev@example.com / password1` and prints a 24h access token. Click "Authorize" in Swagger and paste the token; all "Try it out" calls send it automatically.

---

## Reset the dev DB (clean start, no migrations needed)

When the dev data gets clumsy and you want a fresh slate without re-running migrations:

```bash
cd <project_dir>/drape && 
source .venv/bin/activate && 
cd backend && 
python scripts/reset_dev_db.py
```

**What it does:**
1. `TRUNCATE` every app table (CASCADE follows FKs; RESTART IDENTITY resets sequences).
2. Re-seeds the 6 starter wardrobe templates from `backend/data/starter_wardrobe_templates.json`.
3. Re-creates the dev user (`dev@example.com / password1`) and prints a fresh access token.

**What it preserves:** schema, indexes, FKs, Postgres enum types, the `alembic_version` row.

**Refuses to run** when `ENVIRONMENT != dev` (never wipes a tbd/prd DB).

**When to use this vs. a full DB wipe:**
- Use the reset script (above) for **routine dev cleanup** — fastest path; no docker churn.
- Use a full docker-volume wipe (below) if you suspect schema drift or are debugging Alembic.

---

## Full DB wipe (only if reset isn't enough)

Nukes the Postgres docker volume entirely.

```bash
# Stop the server first (Ctrl+C)

# Wipe the volume + restart Postgres
cd <project_dir>/drape && docker compose down -v && docker compose up -d

# Wait ~3s, then re-apply migrations + seed
source .venv/bin/activate && cd backend && alembic upgrade head && python scripts/seed_dev_user.py

# Restart the server
uvicorn app.main:app --reload
```

`alembic upgrade head` re-runs the squashed init migration (which auto-seeds starter wardrobe templates), so the starter wardrobe data is back without an extra step.

---

## API smoke tests (curl + bash) — `backend/api_tests/`

The fastest way to check that every endpoint is wired and serving correctly. Doubles as living documentation — each script shows the canonical request body and expected status for a resource group.

**Full smoke run from a clean DB:**

```bash
cd <project_dir>/drape && source .venv/bin/activate && cd backend && bash api_tests/run_all.sh
```

This resets the DB, then runs scripts 01–08 in order. Each prints `[PASS]` / `[FAIL]` lines; the run exits non-zero on the first failure.

**Run individual scripts** (after `bash api_tests/reset.sh` once):

```bash
bash api_tests/01_auth.sh             # signup, login, refresh, /users/me
bash api_tests/02_profile.sh          # onboarding: shopping-style → goals → measurements
bash api_tests/03_starter_wardrobe.sh # template assignment + idempotency
bash api_tests/04_wardrobe.sh         # CRUD + log-worn + favorites + scanner + IDOR check
bash api_tests/05_today.sh            # dashboard, force-generate
bash api_tests/06_outfits.sh          # reasoning, regenerate, mix-and-match, log, history
bash api_tests/07_usage.sh            # current-week, drive 22nd → 429
bash api_tests/08_analytics.sh        # cost-per-wear, utilization, intelligence Pro gate
```

**Why bash + curl:**
- **Discoverable** — read `04_wardrobe.sh` and you've learned the wardrobe API.
- **Zero install** — only `curl` + `jq` (`brew install jq` if missing).
- **Copy-paste friendly** — lift any `curl` line into Postman/Insomnia.
- **Doubles as docs** — the request bodies in the scripts are the canonical examples.

**Tradeoff:** no structured assertions and no isolation between scripts. When schema changes start cascading into opaque downstream failures, the planned pytest harness ([`PROJECT_STATUS.md`](./PROJECT_STATUS.md) §"API testing") is the next step.

See [`backend/api_tests/README.md`](./backend/api_tests/README.md) for the full reference (helpers, token cache, gotchas).

---

## Pytest suite — `backend/tests/`

Structured regression tests with real assertions. Complementary to the bash smoke tests:
- **bash + curl** = quick "did I break anything obvious?" + living docs.
- **pytest** = "exact contract — error codes, body shapes, edge cases." Catches regressions when a response field renames or a status code changes.

### One-time setup

Creates `drape_test` Postgres DB + installs pytest stack. Run once per fresh checkout:

```bash
cd <project_dir>/drape && source .venv/bin/activate && cd backend
pip install -r requirements-dev.txt
bash tests/init_test_db.sh
```

### Run tests

All commands assume you've `cd`'d to `backend/` with the venv active:

```bash
# Whole suite (currently 67 tests, ~19s):
pytest

# One file:
pytest tests/api/routes/test_auth.py
pytest tests/api/routes/test_wardrobe.py
pytest tests/api/routes/test_outfits.py

# Single test, verbose:
pytest tests/api/routes/test_auth.py::test_login_with_valid_credentials -vv

# Show captured stdout/log even on pass (useful for debugging):
pytest -s

# Match a name pattern:
pytest -k "log_worn or favorite"
pytest -k "not slow"

# Stop on first failure:
pytest -x

# Re-run only the tests that failed last time:
pytest --lf

# With branch coverage:
pytest --cov=app --cov-report=term-missing

# Open the coverage HTML report:
pytest --cov=app --cov-report=html && open htmlcov/index.html
```

**If something looks broken,** these often help:

```bash
# Clear pytest cache (rare; usually plugin issues):
rm -rf .pytest_cache

# Re-init the test DB schema (after squashing migrations):
psql "postgresql://admin:password@localhost:5433/postgres" -c "DROP DATABASE drape_test"
bash tests/init_test_db.sh
```

### Where things live

| Path | What |
|---|---|
| `backend/tests/conftest.py` | shared fixtures: test DB engine, truncate-between-tests, TestClient with canned providers, `make_user` / `auth_headers` / `authed_client` |
| `backend/tests/factories.py` | hand-rolled data builders: `make_wardrobe_item`, `make_starter_wardrobe`, `make_outfit` |
| `backend/tests/api/routes/test_*.py` | per-resource HTTP round-trip tests |
| `backend/tests/services/test_*.py` | (planned) service-layer unit tests for pure logic |
| `backend/tests/init_test_db.sh` | one-time test DB setup |
| `backend/pytest.ini` | pytest config (test paths, markers, asyncio mode) |
| `backend/requirements-dev.txt` | pytest + pytest-asyncio + pytest-cov |

### How tests stay isolated

- A separate `drape_test` database is used. `conftest.py` sets `DATABASE_URL` before any app module imports, and refuses to run if the URL doesn't contain "test" — a safety guard against accidental dev wipe.
- After every test, the autouse `_truncate_after_test` fixture truncates every app table (CASCADE, RESTART IDENTITY; preserves `alembic_version`).
- AI / weather / image-storage providers are swapped via `app.dependency_overrides`. Same `_CannedAIProvider` / `_StubWeatherProvider` from `scripts/verify_phase_6c.py` — single source of truth for canned response shapes. Image uploads land in a per-test `tmp_path` so nothing leaks to `./uploads/`.
- Auth tokens for tests are minted directly via `create_access_token` (bypasses `/auth/login` — faster). Tests that *want* to exercise login call it explicitly.

### What's covered (as of latest run: 67 tests in 19s)

| File | Tests | Surface |
|---|---:|---|
| `test_auth.py` | 15 | signup (happy + duplicate + 4 weak-password variants + missing terms), login (valid + wrong-pw + unknown-user), refresh rotation + revocation, `/users/me` (valid + missing + garbage) |
| `test_wardrobe.py` | 27 | CRUD + list/filter/paginate, validation, log-worn idempotency, favorites, scanner (mock AI), multipart image upload, cross-user IDOR → 404, free-tier 30-item limit + Pro bypass |
| `test_outfits.py` | 25 | dashboard (empty / 3-outfit / caching / image_url=null), generate force, reasoning + cross-user, regenerate (disjoint items + 404), mix-and-match (swap + round-trip + determinism + cross-user item rejection), log + 3 toast variants + idempotency, history filters |

Coming next: `test_usage.py` (limit + Pro bypass + week-window math), `test_analytics.py` (cost-per-wear + intelligence Pro gate), `test_starter_wardrobe.py`, `test_profile.py`.

---

## Verify scripts (per-phase smoke tests)

Each phase ships a verify script that exercises its routes end-to-end against a `_CannedAIProvider` (offline, deterministic):

```bash
cd <project_dir>/drape && source .venv/bin/activate && cd backend
python scripts/verify_phase_6a.py    # AI + weather providers
python scripts/verify_phase_6b.py    # wardrobe scanner + batch upload
python scripts/verify_phase_6c.py    # outfit generation + today + history + mix-and-match
python scripts/verify_phase_6d.py    # usage limits + analytics + Pro gate
```

Each prints a `[PASS]` / `[FAIL]` line per check and exits non-zero on failure.

---

## Connecting a Flutter client to the backend (Phase 9, was Phase 8)

When you resume app development, this is the practical wiring. Conceptual plan + sub-phases live in [`PROJECT_STATUS.md`](./PROJECT_STATUS.md) §"Phase 9 — Flutter mobile client" (body still uses original 8a–8h markers per §1 mapping); known backend gaps the client must design around are in [`PROJECT_STATUS.md`](./PROJECT_STATUS.md) §"Known gaps / deviations".

**1. The contract = `openapi.json`.** Don't hand-write Dart models. With the server running:

```bash
curl -s http://localhost:8000/openapi.json > mobile/openapi.json
# Phase 9a wires tools/openapi_gen.sh to regenerate the Dart client from this.
```

**2. Base URL per Flutter flavor:**

| Flavor | Base URL | Notes |
|---|---|---|
| dev (iOS simulator) | `http://localhost:8000/api/v1` | simulator shares the host network |
| dev (Android emulator) | `http://10.0.2.2:8000/api/v1` | `10.0.2.2` is the emulator's alias for host `localhost` |
| dev (physical device) | `http://<your-LAN-ip>:8000/api/v1` | run uvicorn with `--host 0.0.0.0`; device + Mac on same Wi-Fi |
| tbd / prd | (set after Phase 10b deploy, was 7b) | from the ALB / CloudFront domain |

**3. Auth handshake the client implements:**
- `POST /api/v1/auth/signup` or `/auth/login` with `{"auth_method":"email","email":...,"password":...}` → `{access_token, refresh_token}`.
- Send `Authorization: Bearer <access_token>` on every authed call.
- On `401`, call `POST /api/v1/auth/refresh-token` with the refresh token (it rotates — store the new one), retry once; on refresh failure, route to login. This is the dio interceptor 9a builds.
- Store tokens in `flutter_secure_storage`.

**4. CORS:** dev backend sets `allow_origins=["*"]` so a local Flutter web build / device works without extra config. (Locked down to an env-driven list in Phase 10a, was 7a.)

**5. Gaps to stub in the client (don't wait on these):**
- **Apple/Google buttons** → dev returns 400 `oauth_unavailable`. Build email/password first; gate social buttons behind a flag until backend Phase 11a (was 7c).
- **Avatar** → no `/avatar/generate` endpoint. Placeholder image in onboarding; product decision pending (see PROJECT_STATUS.md gaps table).
- **Pro upgrade** → real Stripe wire-up is Phase 11c (was 7e); local subscription state machine is Phase 8b (`StubPaymentProvider`). To test Pro-gated UI before 8b ships, flip the column directly:
  ```bash
  python -c "from app.core.config import settings; from sqlalchemy import create_engine, text; e=create_engine(settings.database_url); c=e.begin().__enter__(); c.execute(text(\"UPDATE users SET subscription_tier='pro' WHERE email='dev@example.com'\")); c.get_transaction().commit()"
  ```
  (or just `docker compose exec db psql -U admin -d drape -c "UPDATE users SET subscription_tier='pro' WHERE email='dev@example.com'"`)
- **Push** → no real provider until Phase 11d (was 7f). `POST /devices/register` doesn't exist yet; defer 9h.
- **Outfit images** → `image_url` is always `null` by design (decision #2). Render the 2×2 grid from each item's `primary_image_url`.

**6. Workflow once the app exists:** keep the backend running (`uvicorn ... --reload`) in one terminal, `flutter run` in another. After any backend route/schema change, re-export `openapi.json` and regenerate the client.

---

## Where to find things

| What | Where |
|---|---|
| All API endpoints (interactive) | http://localhost:8000/docs |
| All API endpoints (text reference) | [`PROJECT_STATUS.md`](./PROJECT_STATUS.md) §10 |
| Route handlers | `backend/app/api/routes/` |
| Service layer | `backend/app/services/` |
| Provider implementations | `backend/app/services/providers/<area>/` |
| SQLAlchemy ORM models | `backend/app/db/models.py` |
| Alembic migrations | `backend/alembic/versions/` (one squashed init while pre-prod) |
| Pydantic schemas | `backend/app/schemas/` |
| Config + settings | `backend/app/core/config.py` |
| Provider container | `backend/app/core/providers.py` |
| Phase status (what's shipped) | [`PROJECT_STATUS.md`](./PROJECT_STATUS.md) §Status snapshot |
| Phase plan (what's next) | [`PROJECT_STATUS.md`](./PROJECT_STATUS.md) §1 + §7 |

---

## Common gotchas

- **`type "user_role" already exists`** when running `alembic upgrade` after a `downgrade`: Postgres enum types survive `op.drop_table`. Either use the full DB wipe path, or drop them manually:
  ```bash
  python -c "
  from app.core.config import settings
  from sqlalchemy import create_engine, text
  e = create_engine(settings.database_url)
  with e.begin() as c:
      c.execute(text('DROP TYPE IF EXISTS user_role CASCADE'))
      c.execute(text('DROP TYPE IF EXISTS auth_method CASCADE'))
  "
  ```
- **`MEASUREMENT_DEK_DEV is required when ENVIRONMENT=dev`**: missing from `.env`. Generate one with `python -c 'import os, base64; print(base64.b64encode(os.urandom(32)).decode())'`.
- **Server won't reload on file changes**: confirm you ran with `--reload`. Watch path is the `cwd` (`backend/`); changes outside that won't trigger.
- **`refusing to seed` from a script**: `ENVIRONMENT` is not `dev`. Check your `.env`.
