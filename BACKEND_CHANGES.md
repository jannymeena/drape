# DRAPE — Backend Changes (Pending Tasks)

**Created:** 2026-07-05 · derived from the gap analysis of `CTO_Handoff_*.md` vs the codebase;
completed work (shipped 2026-07-05, 198 tests green) removed — record in git history.
**Reordered:** 2026-07-06 · execution order: Tier 1 buildable now → Tier 2 blocked on
keys/accounts → Tier 3 hardening + AWS deploy → optional last. The parking lot was dissolved
into the tiers. The 2D-avatar removal is confirmed but stays a **note** (see the Avatar note
at the end), not a scheduled task.
**Updated:** 2026-07-07 · the settings-privacy follow-on (old 1.3) was resolved with **no
backend work** — mobile dropped the Connected Apps rows (no integrations exist); Tier 1
renumbered. `ReasoningItem` gained `category`/`color_name` (additive, shipped with mobile P2).
**Updated:** 2026-07-07 (later) · Tier 2 OAuth (old 2.1) **shipped** — `RealOAuthVerifier`
does JWKS signature/issuer/audience verification for Apple + Google (comma-separated
client IDs supported for multi-platform audiences); verification failures map to 401
`oauth_invalid_token`. No new config keys. Tier 2 renumbered. Mobile buttons follow
(MOBILE_CHANGES P2). Also shipped: **`DISABLED_FEATURES`** env key (feature switches;
known names `apple_login`, `google_login`) — a disabled feature's config keys are not
required at startup and its sign-in answers 400 `oauth_unavailable`, so tbd can launch
before Apple/Google credentials are approved. Boot-time flag: flipping it = redeploy.
Extend `_KNOWN_FEATURES` (`core/config.py`) when Stripe/push land if they need switches.
**Updated:** 2026-07-07 (evening) · Tier 2 Stripe (old 2.1) **shipped** behind the `billing`
feature switch (`DISABLED_FEATURES=billing` ⇒ Stripe keys not required, billing endpoints
400 `billing_unavailable`; dev keeps `MockPaymentProvider` regardless). `StripeProvider`
over raw httpx (no SDK dep): subscriptions charge the configured price
(`STRIPE_PRICE_ID_PRO_*`, `error_if_incomplete`), soft-cancel maps to
`cancel_at_period_end`, customers keyed by `metadata[user_id]` (search + deterministic
idempotency key — no schema change), portal via `POST /billing/portal`. Webhook
`POST /billing/webhook/stripe` (HMAC-verified, replay-guarded): `invoice.paid` cycle →
extend period + history row; `payment_failed` → failed row only (Stripe retries);
`subscription.deleted` → drop to free. Config: `STRIPE_WEBHOOK_SECRET`,
`STRIPE_PRICE_ID_PRO_MONTHLY/_YEARLY`, `STRIPE_PORTAL_RETURN_URL`. Tier 2 renumbered.
**Mobile follow-up (→ MOBILE_CHANGES):** payment-method `token` must become a real Stripe
PaymentMethod id (`pm_...`) from the Stripe SDK in tbd/prd; mock accepts anything in dev.
**Updated:** 2026-07-08 · **Tier 1 shipped** (all three buildable items; only the deploy-time
reset-URL default remains, renumbered 1.1). **1.3 prompt caching:** outfit prompts restructured
— stable prefix (persona, JSON schema, wardrobe, goals, wearer/fit) moved into `system` with
`cache_control` (new `cache_system` flag on `AIProvider.chat`); volatile occasion/weather stay
in the user turn. Cache reads bill ~10% of base input across the per-occasion burst;
`ai_usage.jsonl` + cost math now record `cache_read/creation_input_tokens` (watch them —
below the model's minimum cacheable prefix, ~4k tokens on Haiku, caching silently no-ops).
**1.2 local streak timing:** new `core/localtime.py` — the app day rolls over at **05:00
user-local** (matches the Monday-05:00 weekly reset + the handoff's 6pm–5am greeting cycle);
streaks, the Today window, the dashboard reset countdown, and history filters all use it
(UTC fallback when timezone is null). **1.1 fit-summary consent path (§5.5.1):** coarse
`fit_profile` (body_shape/height_band/build — categorical only, never cm) derived at
measurements submit and stored on `user_measurements` (plaintext by design; dies with the
row on DELETE /account); separate `use_measurements_for_fit` opt-in on `users` (+consent
timestamp, set on grant / cleared on revoke, PATCH /users/{id}, in the export snapshot);
single consent choke point `measurements_service.fit_profile_for_user` feeds the outfit
prompt's "Fit:" line. Privacy contract lives in `app/services/fit_profile.py`. Schema change
squashed into the init migration — **local dev + test DBs were wiped/reseeded**.
**Mobile follow-ups (→ MOBILE_CHANGES):** consent toggle UI (P4, with the privacy-policy line);
Today's `usage.resets_at` is now the 5am-local rollover (was UTC midnight).
**Updated:** 2026-07-07 (late) · Push **delivery half shipped** behind the `push` switch:
real `ApnsFcmProvider` (FCM HTTP v1, service-account OAuth minted locally via pyjwt — no
firebase-admin dep; APNS relay via the .p8 uploaded to the Firebase project).
`FCM_CREDENTIALS_JSON` accepts raw or base64 JSON. `DISABLED_FEATURES=push` ⇒ creds not
required, `notify_user` fan-out becomes a logged no-op (device registration keeps working
— pushes are server-initiated, so no 400 contract). Dead tokens logged as
`push.fcm.unregistered` (pruning = future nicety). The **18 campaigns + scheduler remain**
(2.1); blocked on the Firebase project + APNS key upload + mobile client (MOBILE_CHANGES P3).
Companion doc: `MOBILE_CHANGES.md`.

Schema convention (pre-prod): fold all new tables into the **single init migration**
(wipe local DB + regenerate), per the squash-don't-ALTER rule. Revert to additive
migrations once prd has real users.

---

## Tier 1 — Buildable now (no outside input)

### 1.1 Reset-password URL default *(trivial)*
- [ ] Config default (`core/config.py`) still points at `https://drape.local/reset`; dev `.env`
      carries the `drape://` template. Set the real https App/Universal Link template at deploy
      time (Tier 3.2 step 7).

## Tier 2 — Blocked on keys/accounts — by build complexity

Each item is blocked on something only you can provide; listed smallest build first.

### 2.1 Push campaigns *(item 11d, remaining half)* — blocked on: FCM/APNS project
- [x] Real `ApnsFcmProvider` — shipped 2026-07-07 behind the `push` switch (see header
      note). Still needed from you: Firebase project + service-account JSON
      (`FCM_CREDENTIALS_JSON`), APNS .p8 uploaded to Firebase, iOS push entitlement.
- [ ] The 18 spec'd campaigns (6 per tab doc: wardrobe nudges, limit warnings,
      price drops, win-back, renewal reminders) on the scheduler.
      Mobile client work follows (MOBILE_CHANGES P3).

### 2.2 AWIN affiliate *(item 11e)* — blocked on: affiliate account / data-source decision
- [ ] Real `AwinProvider` replacing the mock catalog `AffiliateProvider`
      (product data source is an open decision — seeded/mock vs real
      affiliate API).

### 2.3 Analytics *(decision 2026-07-05)* — blocked on: PostHog project + key
- [ ] Recommended: PostHog Flutter SDK direct-to-PostHog — **no backend work** beyond adding
      the project key to config. Only if we later want first-party capture does a `/events`
      proxy endpoint make sense. Mobile implements the events (MOBILE_CHANGES P1).

## Tier 3 — Production hardening & AWS deploy *(items 10a/10b/11b)*

**Nothing in this tier is built** — no Dockerfile, task definitions, IaC, or CI exist in the
repo yet; this is the target runbook. All resources in **`ca-central-1`** (PIPEDA); `tbd` and
`prd` fully isolated (separate VPC / RDS / KMS / ECS services), same image, different env vars.

### 3.1 Pre-deploy hardening *(item 10a)*
- [ ] Sanitize Pydantic `Settings` validation errors — they echo the input dict incl. secrets
      (memory: `project_pydantic_error_leak`).
- [ ] CORS: `allow_origins=["*"]` in `app/main.py` is dev-only — restrict per env.
- [ ] Rate-limit `/auth/login`, `/auth/forgot-password`, `/auth/reset-password` (unbounded today).
- [ ] Pagination caps; orphaned-image GC.
- [ ] WAF in front of the ALB; CloudWatch alarms (5xx rate, p95 latency, RDS CPU, free storage).
- [ ] RDS automated backups + a periodic manual snapshot; PITR in prd.
- [ ] SES domain out of sandbox before prd (tbd may stay sandboxed).

### 3.2 AWS infrastructure *(item 10b)* — first-time `tbd` setup, in order

| Component | Service |
|---|---|
| Registry / compute / LB | ECR → ECS Fargate behind an ALB (TLS terminator, health check `/api/v1/health`) |
| Database | RDS for PostgreSQL 16 (`pgvector` available; single-AZ tbd, multi-AZ prd) |
| Secrets / encryption | Secrets Manager + a KMS CMK per env (measurement envelope encryption) |
| Email / storage / logs | SES · S3+CloudFront (images) · CloudWatch Logs (structlog JSON with `request_id`) |

1. [ ] Account prep: MFA on root, IAM admin role, CLI profile; default region `ca-central-1`
       everywhere — spot-check before every console action (wrong region = accidental PIPEDA violation).
2. [ ] VPC: 2 private subnets (RDS) + 2 public (ALB) across 2 AZs; NAT gateway so tasks reach
       Anthropic / SES / Apple JWKS; SGs: ALB → task:8000, task → RDS:5432.
3. [ ] RDS PG16, DB `drape_tbd` (`db.t4g.medium` fine); master creds auto-created in Secrets Manager;
       then connect once (bastion/SSM) and `CREATE EXTENSION IF NOT EXISTS vector;`.
4. [ ] KMS CMK `alias/drape-tbd-measurements`; key policy: task role gets
       `kms:Encrypt/Decrypt/GenerateDataKey` only. Key ARN → `KMS_KEY_ID`.
5. [ ] SES: verify sending domain + `no-reply@` from-address → `SES_REGION`, `SES_FROM_ADDRESS`.
6. [ ] OAuth creds: Apple Service ID (e.g. `com.drape.app`) + `.p8` private key (record Team/Key IDs;
       `.p8` contents into Secrets Manager); Google OAuth clients (iOS + Android) — the backend only
       needs `GOOGLE_CLIENT_ID` as the audience (verification is JWKS-based).
7. [ ] Secrets Manager: one JSON secret per env (e.g. `drape/tbd/app`) holding the full `.env`
       envelope — `JWT_SECRET` (64-byte urlsafe), `DATABASE_URL`, `ANTHROPIC_API_KEY`, Apple/Google
       IDs, `SES_*`, `KMS_KEY_ID`, `AWS_REGION`, `PASSWORD_RESET_URL_TEMPLATE` (https App/Universal
       Link in prod). `backend/.env.example` is the canonical key list — everything in it must be
       present in the secret.
8. [ ] ECR repo `drape` + lifecycle policy (keep last N tagged, expire untagged after 7 days).
9. [ ] `backend/Dockerfile` — `python:3.11-slim` + `build-essential libpq-dev`, copy
       `app/ alembic/ alembic.ini scripts/`, `EXPOSE 8000`, `ENTRYPOINT scripts/entrypoint.sh`
       which materializes `.env` from Secrets Manager (`get-secret-value` → JSON → `.env` lines)
       before exec-ing `uvicorn app.main:app --host 0.0.0.0 --port 8000` — per the .env policy
       (the image never ships secrets).
10. [ ] Two task definitions per env, same image: **`drape-tbd-app`** (long-running, CPU 512 /
        mem 1024; task role: `secretsmanager:GetSecretValue` on `drape/tbd/*` + KMS on the CMK +
        `ses:SendEmail`; container health check `curl -f localhost:8000/api/v1/health`) and
        **`drape-tbd-migrate`** (one-shot, CMD `alembic upgrade head`).
11. [ ] First migration via `aws ecs run-task --task-definition drape-tbd-migrate` — wait for exit 0
        (alembic output in CloudWatch). Then create the service: 2 desired tasks, ALB target group,
        deployment circuit breaker on, rolling min/max 100/200%.
12. [ ] Smoke test: `/api/v1/health` 200 · OAuth route returns **401 not 404** (mounted in tbd,
        unlike dev) · `forgot-password` → 202 / SES delivery · CloudWatch shows JSON logs with
        `request_id` (pretty colored logs ⇒ `ENVIRONMENT` isn't `tbd`; fix before anything else).
13. [ ] DNS: Route53 alias `api-tbd.drape.app` → ALB; ACM cert `*.drape.app` on the listener.
14. [ ] Record every provisioned ARN (RDS, KMS, ECR, ECS service, secret) in `infra/`.

### 3.3 CI + release flow *(lands with 3.2)*
- [ ] CI on merge to master: `pytest` + `alembic upgrade head` against a throwaway Postgres →
      build/push `drape:tbd-<git-sha>` to ECR → update both task definitions.
- Release order, always: **run the migrate task first** (wait exit 0; if it fails, do NOT roll the
  service forward — forward-fix, push, retry), then
  `aws ecs update-service --force-new-deployment` (rolling; circuit breaker auto-rolls back on
  failed health checks).
- Promote to prd: re-tag the **same SHA**, run the prd migrate task, deploy — only after tbd has
  been green for a while; watch CloudWatch alarms ~10 min before walking away.
- Rollback: bad-but-healthy release → previous task-def revision; bad migration →
  **forward-fix, never `alembic downgrade`** in tbd/prd; compromised `JWT_SECRET` → rotate secret +
  `--force-new-deployment` + `UPDATE refresh_tokens SET revoked_at = now()`; compromised CMK →
  rotate (old ciphertexts decrypt via the old key version transparently).
- Day-2 ops: `aws logs tail /ecs/drape-tbd --follow` · Logs Insights `filter request_id = "..."` ·
  one-off SQL via SSM bastion only (never open RDS to the internet) · restart / pick up new secrets:
  `update-service --force-new-deployment` with no task-def change.

### 3.4 KMS envelope encryption *(item 11b)* — after 3.2
- [ ] Real `KmsEnvelopeEncryptor` + measurement DEK rotation (stub raises `NotImplementedError`;
      dev uses `LocalAesEncryptor` with `MEASUREMENT_DEK_DEV`).

## Optional / last

- [ ] **Outfit composite image generation** *(item 11f)* — `image_url` stays `null` by design;
      the client renders the 2×2 grid from item images. Build only if the product wants it.
- [ ] **Support attachments** — `POST /support/*` has no attachment field; mobile removed the
      Contact Us attach control on that basis (2026-07-07). Build (S3 upload + reference in
      `extra`) only if the product wants in-app screenshots on bug reports.
- **2FA + `PUT /account/phone`** — no design; cut for v1. Revisit only if a design lands.
  (The mocked 2FA switches were removed from mobile 2026-07-07.)

---

## 📝 Note — Avatar (confirmed for removal 2026-07-06; do NOT implement)

The **2D avatar** concept is being removed. Consequences for the backend, recorded here so
nobody builds against the handoff doc:

- The parametric `POST /avatar/generate` pipeline from the Onboarding handoff is
  **permanently N/A** — do not build it.
- What stays (for now) is the *photo* path: `POST /profile/avatar/upload` +
  `avatar_analysis.analyze_body` → `Profile.body_analysis` feeding the outfit prompt
  "Wearer:" block. When the removal work is scoped, decide whether body/skin analysis
  survives as a standalone **style photo** feature or goes too — it is the §5.5
  personalization link, so removing it silently would regress outfit quality
  (recommended: keep it).
- `user_avatars` / avatar fields cleanup happens with the removal work, not before
  (squash into the init migration when it does).
- The measurements→fit-summary path (**shipped 2026-07-08**) is independent of the avatar and
  proceeds regardless. Mobile-side consequences are in the MOBILE_CHANGES avatar note.

*(The §5.5.1 design note — measurements → outfit personalization, the PIPEDA-safe way — was
implemented 2026-07-08; the privacy contract now lives in `app/services/fit_profile.py` and the
consent gate in `measurements_service.fit_profile_for_user`. The only outstanding piece is the
privacy-policy line + consent toggle UI, tracked in MOBILE_CHANGES P4.)*
