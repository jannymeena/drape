# API smoke tests (curl + bash)

Lightweight, dependency-free smoke tests that exercise the live HTTP surface. They double as **living documentation** — every endpoint we ship has a curl invocation here showing the request body and the expected status.

> **Not a regression suite.** For pytest-style coverage with structured assertions, see [`plan.md`](../../plan.md) §"API testing" (planned, not yet built).

## Requirements

- Server running on `http://localhost:8000` (override with `BASE_URL`).
- Python venv active (`source ../../.venv/bin/activate`) and `cwd=backend/`.
- `curl`, `jq`, `python` (the last one for DB-state setup in scripts 7 & 8).

## Quick start

```bash
# Full smoke run from a clean state:
bash api_tests/run_all.sh

# Or run individual scripts after a reset:
bash api_tests/reset.sh
bash api_tests/01_auth.sh
bash api_tests/02_profile.sh
# ...
```

Each script prints `[PASS]` / `[FAIL]` lines and exits non-zero on failure.

## What's where

| Script | Surface exercised | Notable side effects |
|---|---|---|
| `_common.sh` | shared helpers (sourced, not run) | — |
| `reset.sh` | wraps `scripts/reset_dev_db.py` + clears token cache | wipes all rows |
| `01_auth.sh` | signup, login, refresh, logout, /users/me, wrong-password 401, duplicate-email 409 | creates a throwaway secondary user |
| `02_profile.sh` | shopping-style → age → goals → measurements; PATCH /users/{id} for tz+location | advances dev user's onboarding |
| `03_starter_wardrobe.sh` | list templates, assign (auto), idempotency check, deactivate | materializes ~9 starter items |
| `04_wardrobe.sh` | manual CRUD, log-worn idempotency, favorites, scanner (mock), cross-user IDOR → 404 | creates + deletes test items |
| `05_today.sh` | dashboard (3 outfits), generate-outfits force, weather + banners | generates outfits today |
| `06_outfits.sh` | reasoning, regenerate, mix-and-match, log → toast=default, history filter | logs an outfit (advances streak) |
| `07_usage.sh` | /usage/current-week, drive 22nd → 429, restore counter | bumps + restores `usage_tracking` |
| `08_analytics.sh` | cost-per-wear, utilization, weekly-report, intelligence Pro gate (402 → 200) | flips `subscription_tier` and back |
| `run_all.sh` | all of the above in dependency order | full reset + run |

## How a script reads

`_common.sh` exports four primitives every script uses:

```bash
auth                        # echoes the cached access token
call METHOD PATH [BODY]     # authenticated request; sets $HTTP_CODE, $HTTP_BODY
call_unauth ...             # same, no Authorization header
expect_status LABEL CODE    # asserts $HTTP_CODE; pretty-prints body on miss
expect_body_field LABEL JQ_FILTER EXPECTED   # asserts a jq filter equals EXPECTED
```

Plus `db_exec SQL` and `db_scalar SQL` for the few state-setup steps that go faster through Postgres than through the API.

## Token caching

The first `auth()` call logs in as `dev@example.com / password1` and writes the access token to `/tmp/drape_dev_token`. Subsequent calls reuse it. `reset.sh` deletes the file, so the next script logs in fresh. Override the test user via `DEV_EMAIL` / `DEV_PASSWORD` envvars.

## Why bash + curl (not pytest)

- **Discoverability.** New collaborators read `04_wardrobe.sh` and learn how the wardrobe API works in 30 seconds.
- **Zero install.** `curl` and `jq` are the only deps; works on any Linux/macOS box.
- **Copy-paste friendly.** Lift any individual `curl` line into Postman/Insomnia.
- **Doubles as docs.** Each script's body is the canonical "this is how the request looks" reference.

The tradeoff: no structured assertions and no isolation. When schema/contract changes start cascading into opaque downstream failures, swap to pytest (planned for a later phase).

## Common gotchas

- **`server not reachable at .../health`** — start the server first: `cd backend && uvicorn app.main:app --reload`.
- **`login failed: ...`** — the dev user doesn't exist yet. Run `bash api_tests/reset.sh` (or `python scripts/seed_dev_user.py`).
- **`07_usage` says limit=21 but expected pro tier`** — that script restores the counter and `subscription_tier` at the end. If a previous run was interrupted mid-script, run `bash reset.sh` to get back to a clean state.
- **`db_exec` errors** — make sure the venv is active and `cwd=backend/` (the SQLAlchemy import resolves from there).
