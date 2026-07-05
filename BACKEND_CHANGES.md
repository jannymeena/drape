# DRAPE — Backend Changes (Gap Closure Plan)

**Created:** 2026-07-05 · derived from the gap analysis of `CTO_Handoff_*.md` vs the codebase.
**Re-ordered:** 2026-07-05 · new tiering: (1) fixes needing no new build, (2) new builds
needing no outside input (API keys etc.), (3) the rest by build complexity.
Companion doc: `MOBILE_CHANGES.md` — its "BE Pn" references map to the "(was Pn)"
tags on each section below.

Schema convention (pre-prod): fold all new tables into the **single init migration**
(wipe local DB + regenerate), per the squash-don't-ALTER rule. Revert to additive
migrations once prd has real users.

---

## Tier 1 — Fixes to existing code (no new tables, no new providers)

Quick wins: pure logic/config changes in code that already exists.

### 1.1 Resume-banner data fix *(was P5)* ✅ **Done 2026-07-05**
- [x] `_profile_incomplete` now checks `UserMeasurements.is_complete` (plain
      column — no decryption) instead of `onboarding_completed`; dashboard
      `banners.incomplete_profile` is finally true for the banner's actual
      audience. New route test covers both directions.
- [x] `GET /profile/onboarding-status` now returns
      `measurement_steps_completed` (0–8) + `next_incomplete_step` via
      `measurements_service.step_progress` (weight optional: 7 required
      fields → complete, never routes to the weight step). *(Mobile follow-up,
      optional: the Today banner can now read the payload instead of computing
      client-side.)*

### 1.1b Streak date-boundary flake ✅ **Done 2026-07-05**
- [x] Streak tests pinned to the service's UTC date (`_utc_today()` helper) —
      was flaky whenever local date ≠ UTC date. **User-local streak timing**
      (CTO doc 2: Monday 5 AM local resets) remains a product follow-up.

### 1.2 Dev config: reset-link template ✅ **Done 2026-07-05**
- [x] Set `PASSWORD_RESET_URL_TEMPLATE=drape://drape.app/auth/reset-password?token={token}`
      in dev `.env` (mobile `drape://` scheme shipped 2026-07-05; config default in
      `core/config.py:38` still points at `https://drape.local/reset`).
      https App/Universal Links are the prod path.

### 1.3 Profile intelligence *(was P3, item 8a)* ✅ **Done 2026-07-05**
- [x] `GET /profile/intelligence` — aggregate utilization %, avg cost-per-wear,
      items unworn 60d+, wardrobe value / total saved. Reuse
      `analytics_service.py` (cost-per-wear + utilization already computed for
      `/wardrobe/analytics/*`); a re-aggregation, not new math. New endpoint,
      zero new schema. Unblocks the fake stat grid (MOBILE_CHANGES P4).

### 1.4 Starter-wardrobe transition logic *(was P4)* ✅ **Done 2026-07-05**
- [x] **Blending** — `_blend_pool` in outfit generation (0 real → starter only;
      1–4 → all real + ≤10 starter; 5–9 → all real + ≤4 starter; 10+ → real only).
- [x] **Auto-deactivation at 15+** — already existed (`recompute_transition`,
      hooked from wardrobe create/delete); verified, untouched.
- [x] **`banners.starter_wardrobe`** now per the doc: active assignment + <5
      real items + not dismissed in 7 days.
- [x] **Dismissal persistence** — `banner_dismissals` table (folded into the
      init migration; dev + test DBs regenerated) + `banner_service` +
      `POST /today/banners/{banner}/dismiss` (7-day window, whitelisted keys).
      **Unblocks both mobile starter banners** (MOBILE_CHANGES P3 + audit A).

## Tier 2 — New builds, no outside input needed ✅ **ALL DONE 2026-07-05**

Everything below runs end-to-end in dev with mock providers (198 backend
tests green). What remains is Tier 3 — each item blocked on keys/accounts.

### 2.1 Support remainder *(was P8, item 8e)* ✅ **Done 2026-07-05**
- [x] Feature-request board: `GET /support/feature-requests` (public list,
      score + caller's vote, ranked) + `POST /support/feature-requests/{id}/vote`
      (+1/-1 upsert, 0 clears) on a new `feature_request_votes` table.
      **Unblocks** the mobile upvote stub (`feature_request_screen.dart:323`)
      — mobile should also swap its hardcoded "popular features" list for the
      board.
- [x] FAQ: *(decision 2026-07-05)* stays static in the mobile app for v1 —
      no backend endpoint.

### 2.2 Billing & Pro *(was P1, item 8b)* ✅ **Done 2026-07-05** — mock provider e2e
The enforcement side already exists (`usage_service.py` 21/3 weekly limits,
30-item wardrobe cap, `require_pro` → 402). What's missing is anything to buy.
- [x] **Tables:** `subscriptions` (soft cancel + lazy expiry — no scheduler),
      `billing_history`, `payment_methods` (init migration; DBs regenerated).
- [x] **`PaymentProvider` interface** — `MockPaymentProvider` in dev;
      `StripeProvider` stub raises until Tier 3.2. Full lifecycle covered by
      10 route tests (upgrade → gates open → cancel → retention → expiry).
- [x] **Endpoints** (Profile handoff §API):
      - `GET /subscription` — current plan, renewal date, status
      - `POST /subscription/upgrade` / `POST /subscription/cancel` (3-step flow:
        reason → retention offer → final confirm)
      - `POST /subscription/retention-offer/accept`
      - `GET /billing/history`, `GET /billing/invoice/{id}`
      - `GET/POST /payment-methods`
- [x] **402/429 payloads now carry `plans`** (price/currency per plan) — the
      mobile paywall (MOBILE_CHANGES P1) is **unblocked**.

### 2.3 Push framework *(was P7 first half, item 11d)* ✅ **Done 2026-07-05**
- [x] `PushProvider` interface + `LogPushProvider` (dev); `ApnsFcmProvider`
      stub raises until Tier 3.3.
- [x] `devices` table + `POST /devices` / `DELETE /devices/{token}` (upsert by
      token; re-registration moves the token to the caller).
- [x] `push_service.notify_user` fan-out (fire-and-forget, never raises) +
      first transactional trigger: limit-reached 429s send a paywall push.
      *Campaign scheduler + the 18 spec'd notifications land with real
      delivery in Tier 3.3.*

### 2.4 Shop backend *(was P2, items 7a–7e)* ✅ **Done 2026-07-05** — mock affiliate e2e
- [x] **7a** `products` + `AffiliateProvider` (mock catalog dev; Awin stub →
      Tier 3.4); `GET /shop/feed` orders thin wardrobe categories first +
      `measurements_complete` flag.
- [x] **7b** advisor ask/history — structured suggestions matched to catalog
      products, persisted per conversation; 10/week `usage_service` resource.
- [x] **7c** `POST /shop/buy-check` (cached `analyze_image` → fit/value/gap
      verdict, persisted + history endpoint); 5/week limit; parse failures
      degrade to a neutral verdict instead of 500.
- [x] **7d** `GET /shop/gap-analysis` — deterministic category-coverage
      heuristic + outfit-unlock counts (no AI spend, so no results table —
      deliberate deviation from the doc's `gap_analysis_results`); free =
      top-gap teaser, Pro = full list.
- [x] **7e** `wishlists` + add/list/remove; save-time price vs provider live
      price surfaces `price_drop_cents` (mock provider ships one dropped item
      for the demo path). Push alerts land with Tier 3.3/3.4.
      **The whole Shop tab (MOBILE_CHANGES P2) is unblocked.**

## Tier 3 — Needs outside input (keys/accounts) — by build complexity

Each item is blocked on something only you can provide; listed smallest build first.

### 3.1 OAuth *(was P6, item 11a)* — blocked on: Apple/Google client IDs
- [ ] `RealOAuthVerifier` — Apple + Google JWKS verification (currently raises
      `NotImplementedError`; dev disables OAuth). Server-side token verification
      per the own-JWT design. Mobile buttons follow (MOBILE_CHANGES P6).

### 3.2 Stripe *(item 11c)* — blocked on: Stripe test keys + price IDs
- [ ] Real `StripeProvider` behind the Tier 2.2 interface (webhook →
      subscription flip, customer portal).

### 3.3 Push delivery *(was P7 second half, item 11d)* — blocked on: FCM/APNS project
- [ ] Real `ApnsFcmProvider` behind the Tier 2.3 interface; APNS entitlement.
- [ ] The 18 spec'd campaigns (6 per tab doc: wardrobe nudges, limit warnings,
      price drops, win-back, renewal reminders) on the scheduler.

### 3.4 AWIN affiliate *(item 11e)* — blocked on: affiliate account / data-source decision
- [ ] Real `AwinProvider` replacing the Tier 2.4 mock (product data source is an
      open decision — seeded/mock vs real affiliate API).

## Tier 4 — Production hardening & AWS deploy *(items 10a/10b/11b)*

*(Absorbed from `DEPLOYMENT_GUIDE.md` + `PROJECT_STATUS.md` §3 on 2026-07-06; both docs deleted.)*
**Nothing in this tier is built** — no Dockerfile, task definitions, IaC, or CI exist in the repo yet;
this is the target runbook. All resources in **`ca-central-1`** (PIPEDA); `tbd` and `prd` fully
isolated (separate VPC / RDS / KMS / ECS services), same image, different env vars.

### 4.1 Pre-deploy hardening *(item 10a)*
- [ ] Sanitize Pydantic `Settings` validation errors — they echo the input dict incl. secrets
      (memory: `project_pydantic_error_leak`).
- [ ] CORS: `allow_origins=["*"]` in `app/main.py` is dev-only — restrict per env.
- [ ] Rate-limit `/auth/login`, `/auth/forgot-password`, `/auth/reset-password` (unbounded today).
- [ ] Pagination caps; orphaned-image GC.
- [ ] WAF in front of the ALB; CloudWatch alarms (5xx rate, p95 latency, RDS CPU, free storage).
- [ ] RDS automated backups + a periodic manual snapshot; PITR in prd.
- [ ] SES domain out of sandbox before prd (tbd may stay sandboxed).

### 4.2 AWS infrastructure *(item 10b)* — first-time `tbd` setup, in order

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

### 4.3 CI + release flow *(lands with 4.2)*
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

### 4.4 KMS envelope encryption *(item 11b)* — after 4.2
- [ ] Real `KmsEnvelopeEncryptor` + measurement DEK rotation (stub raises `NotImplementedError`;
      dev uses `LocalAesEncryptor` with `MEASUREMENT_DEK_DEV`).

## Analytics — deferred (decision 2026-07-05)

The handoff docs assume ~50 client-side events (PostHog). Recommended: PostHog
Flutter SDK direct-to-PostHog, **no backend work** beyond adding the project key
to config. Only if we later want first-party capture does a `/events` proxy
endpoint make sense. Mobile P5 parked; revisit before launch.

## Design note — measurements → outfit personalization, the PIPEDA-safe way *(§5.5.1; deferred, not cancelled)*

*(Moved from `PROJECT_STATUS.md` §5.5.1 on 2026-07-06. The photo half of §5.5 is built — body/skin
from the avatar → `Profile.body_analysis` → outfit-prompt "Wearer:" block. This is the remaining,
consent-gated half. POC reference: `cli_claude.py`.)*

`UserMeasurements` (`models.py`) stores height/weight/shoulders/chest/waist/inseam/hips as encrypted
ciphertext — personal, arguably *sensitive*, information under **PIPEDA** (the reason for
`ca-central-1` + own-JWT + encryption at rest). Feeding it to outfit generation means *decrypting* it
and *disclosing* it to a third-party US processor (Anthropic) — allowed, but only if **consented,
disclosed, and minimized** (PIPEDA hooks: consent, identified purpose, limiting use/disclosure,
safeguards, data minimization). Five points:

1. **Derive, don't disclose.** Convert raw measurements server-side into a coarse **fit profile**
   before the prompt: chest/waist/hip ratio → body shape (rectangle/triangle/inverted-triangle/
   hourglass); height band (petite/average/tall); build (slim/regular/broad) from shoulders+chest.
   Prompt gets e.g. *"Wearer: tall, athletic build, broad shoulders — favor structured fits"* —
   **exact cm never leave our infra** (matches the POC: it inferred body type, didn't ship numbers).
2. **Explicit, separate, opt-in consent** (default **off**): *"Use my measurements to personalize
   fit. We send a general body-shape summary (not exact measurements) to our AI provider."* Store
   consent flag + timestamp (mirror `community_share_avatar`).
3. **Raw numbers stay server-side only.** Decryption never leaves the backend; the AI usage log
   (`ai_usage.jsonl`) must capture the derived block, not raw measurements.
4. **Privacy-policy transparency.** One line: measurements may be used in derived/generalized form
   to personalize recs via a US-based AI processor (PIPEDA cross-border-transfer disclosure).
5. **Honor deletion.** `DELETE /account` must purge any cached derived fit profile alongside the
   encrypted measurements.

## Parking lot / deferred

- **Anthropic native prompt caching** — `cache_control` on the repeated outfit-gen prefix
  (~90% cheaper input tokens); revisit in a later stage.
- **2FA + `PUT /account/phone`** — no design; cut for v1 (mobile removed the Phone row in its
  P9 sweep).
- **Outfit composite image generation** *(item 11f, optional)* — `image_url` stays `null` by
  design; the client renders the 2×2 grid from item images.
- **Settings 8c follow-on** — privacy rows with no backend field (revoke Google Calendar/Instagram,
  correct-my-data): build the fields or drop the rows (see MOBILE_CHANGES P9 leftovers).

---

## 📝 Note — Avatar (do NOT implement; 2D avatar being removed)

We are planning to **remove the 2D avatar** concept. Consequences for the backend,
recorded here so nobody builds against the handoff doc:

- The parametric `POST /avatar/generate` pipeline from the Onboarding handoff is
  **permanently N/A** — do not build it.
- What stays (for now) is the *photo* path: `POST /profile/avatar/upload` +
  `avatar_analysis.analyze_body` → `Profile.body_analysis` feeding the outfit
  prompt "Wearer:" block. When the removal decision is finalized, decide whether
  body/skin analysis survives as a standalone "style photo" feature or goes too —
  it is the personalization link (§5.5), so removing it silently would regress
  outfit quality.
- The consent-gated measurements→fit-summary path (§5.5.1) is independent of the
  avatar and remains deferred, not cancelled.
- `user_avatars` / avatar fields cleanup happens with the removal work, not before.
