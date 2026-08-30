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

**Updated:** 2026-08-30 · **Onboarding rebuilt as the 7-step Style Blueprint** (designs:
`handoff/Style_Blueprint_7_Step/style_blueprint_*_of_7_*`). The old 15-screen chain
(shopping style → age → goals → 8 measurement steps → avatar reveal) collapses to seven
question screens plus a reveal. Changes:
- `users.style_profile` **JSONB** holds the steps 2–7 answers (body shape, tops/bottoms fit,
  style aesthetics, undertone, colour palettes, occupation, dress code, impression goal,
  shopping feeling, accessories, brand tier, three-month feeling). One blob rather than 13
  columns: the answer set is design-driven and still moving, and nothing queries an
  individual answer. Validated by Literals in `schemas/profile.py`. Squashed into the init
  migration per the pre-prod convention — **re-init your dev + test DBs**
  (`psql … -c "DROP DATABASE drape_test"` then `bash tests/init_test_db.sh`).
- `POST /profile/{shopping-style,age-range,style-goals}` are **replaced** by
  `POST /profile/style-blueprint/{identity,fit,aesthetics,color,lifestyle,habits,goals}`
  plus `…/complete` (the reveal's "Build My Wardrobe"). One POST per screen, each returning
  the next step, as before. `shopping_style` / `age_range` / `style_goals` keep their own
  columns — starter-wardrobe matching reads them.
- `OnboardingStep` literals are now `style_blueprint_1…7` → `style_blueprint_reveal` →
  `today_dashboard`. The pre-redesign ids stay accepted by save-progress (so the standalone
  measurement screens don't 422) but resolve to step 1 via `_LEGACY_STEPS`; drop that set
  once no stored `onboarding_last_step` uses them.
- **Measurements left the onboarding chain.** `measurements_service.submit` no longer writes
  `onboarding_last_step` (it would rewind a user who has finished the blueprint) and
  `MeasurementsSubmitResponse` lost its `next_step`. Measurements are now entered from the
  Shop/Profile tabs. `onboarding-status` still reports `measurement_steps_completed` for the
  Today resume banner.
- `onboarding-status` gained a `style_profile` object so a resumed flow prefills.
- `api_tests/02_profile.sh` walks the new eight-call sequence.

**Updated:** 2026-08-30 (starter wardrobe retirement) · Two fixes, from a user
report that uploading 10 items didn't retire the starter kit:

- **`AUTO_DEACTIVATE_REAL_ITEMS` 15 → 10.** The handoff docs disagree — doc 2
  (Today tab) says 15, doc 3 (Wardrobe tab) says 10 — and 10 is what everything
  else already used: the client banner literally counts down to it
  ("n/10 ITEMS TO UNLOCK REAL WARDROBE MODE"), doc 3's banner logic hides at
  `real_items >= 10`, and `outfit_service._blend_pool` switches to real-only at
  10. The app was promising a threshold the backend then refused to honour.
  **Doc 2's 15 is now the stale number** — worth correcting there.
- **A retired starter wardrobe now drops out of the wardrobe listing.** Doc 3
  §Banner States 3 is "user now sees 100% real wardrobe", but deactivation only
  flipped `is_active` and the items kept listing. `wardrobe_service.list_for_user`
  now excludes them once the assignment is inactive. The rows are **kept, not
  deleted**, so the transition counts stay auditable, already-generated outfits
  that reference them still resolve, and an explicit `is_starter_wardrobe=true`
  filter still returns them.

**Not changed — needs a product call:** outfits already generated today are
persisted, so they keep showing starter items until they're regenerated (the
per-card regenerate produces real-only immediately; verified). Auto-regenerating
on retirement would burn 3 generations from the user's weekly quota without them
asking, so it's left alone.

**Updated:** 2026-08-30 (duplicate outfit cards) · The dashboard could show one
occasion twice and drop another entirely. `regenerate` **appends** a new outfit
row rather than replacing the prior one — despite its docstring saying
"replaces the existing outfit row" — and `GET /today/dashboard` sliced the
newest 3 of the day. One regenerate therefore produced
`casual(new), casual(old), date_night` and pushed `work` off the dashboard.

`outfit_service.todays_outfits` is the fix: newest generation **per occasion**,
in canonical order, capped at the daily target. The superseded generation stays
in history, as the original comment intended. The route was also reaching into
the private `_today_outfits` and applying the cap itself — that rule now lives
in the service, per the routes→services tier rule.

Schema convention (pre-prod): fold all new tables into the **single init migration**
(wipe local DB + regenerate), per the squash-don't-ALTER rule. Revert to additive
migrations once prd has real users.

---

## Tier 1 — Buildable now (no outside input)

### 1.1 Reset-password URL default *(done 2026-07-18, Zoura rename pass)*
- [x] Config default, dev `.env`, `.env.example`, and the App Runner yaml all carry
      `zoura://zoura.style/auth/reset-password?token={token}`, matching the mobile intent
      filter (verified end-to-end via the logged dev reset email). Swap to the real https
      App/Universal Link template at prd deploy time (§3.2B step 7; tbd keeps `zoura://`).

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

All resources in **`ca-central-1`** (PIPEDA); `tbd` and `prd` fully isolated (separate
VPC / RDS / KMS / compute), same image, different env vars.

**Two separate AWS setups (decided 2026-07-19):** tbd and prd share *nothing* but the
account, region, and application code. **§3.2A = tbd** (one EC2, native install, Ansible,
~$13.75/mo — settled, build now). **§3.2B = prd** (ECS Fargate + ALB + RDS multi-AZ —
target runbook, build at go-live; nothing from the tbd EC2 is reused or migrated).
App Runner **closed to new customers 2026-04-30** (service in maintenance; AWS successor
is ECS Express Mode), so `infra/drape-test-apprunner.yaml` and
`infra/README-test-deploy.md` are legacy/undeployable — superseded by §3.2A.

### 3.1 Pre-deploy hardening *(item 10a)*
- [ ] Sanitize Pydantic `Settings` validation errors — they echo the input dict incl. secrets
      (memory: `project_pydantic_error_leak`).
- [ ] CORS: `allow_origins=["*"]` in `app/main.py` is dev-only — restrict per env.
- [ ] Rate-limit `/auth/login`, `/auth/forgot-password`, `/auth/reset-password` (unbounded today).
      Observability half landed 2026-07-18: failed logins emit `auth.login_failed` with a sha256
      `email_fp` (raw emails never logged — PII + typed-password-in-email-field leak vector), so a
      CloudWatch metric filter on repeated `email_fp` can alarm on stuffing before limits exist.
- [ ] Pagination caps; orphaned-image GC.
- [ ] WAF in front of the ALB; CloudWatch alarms (5xx rate, p95 latency, RDS CPU, free storage).
- [ ] RDS automated backups + a periodic manual snapshot; PITR in prd.
- [ ] SES domain out of sandbox before prd (tbd may stay sandboxed).

### 3.2A — tbd stack: one EC2, native install (no Docker), full app — **DEPLOYED 2026-07-19**

**Live.** `{"status":"ok"}` on the box; providers.built shows the full tbd set (SES, KMS
envelope, S3 images, real Google OAuth, Stripe, FCM, mock affiliate); alembic migrated;
JSON logs. All IDs/ARNs + day-2 runbook: **`infra/README-tbd.md`**. Stack `zoura-tbd`
(`infra/zoura-tbd.yaml`), Ansible in `infra/ansible/`. Remaining (user): Namecheap A +
3 DKIM CNAMEs, gmail SES verification click; then Stripe tbd webhook + mobile smoke run.

Runs `ENVIRONMENT=tbd` — the full application (SES, KMS, S3, Stripe sandbox, Google login,
FCM push, Anthropic; `DISABLED_FEATURES=apple_login,affiliate`). **~$13.75/mo running 24/7**
(decisions 2026-07-19: no stop/start, real IPv4, **no Cloudflare** — $3.65 of the bill is
the IPv4 fee; $10 on-demand is not reachable under these constraints). New-account free
credits ($100–200) likely cover 7–14 months — check first; 1-yr Compute Savings Plan
(~30% off instance → ~$11.75) only once tbd proves long-lived. All resources `zoura-tbd-*`;
DB `zoura_tbd`; keys reused from dev `.env` except DATABASE_URL / KMS_KEY_ID /
IMAGE_BUCKET / STRIPE_WEBHOOK_SECRET / SES_* (new).

- Compute: 1× **EC2 t4g.micro — confirmed 2026-07-19** (2 vCPU / 1 GB, arm64 Graviton;
  whole Python dep set ships arm64 wheels; x86 escape hatch t3.micro +$1.75/mo), Ubuntu 24.04,
  public subnet, outbound via IGW — **no NAT, no RDS, no Docker/ECR** (dockerd/containerd
  eat ~100–150 MB RAM — meaningful at 1 GB). 2 GB swapfile. Upgrade: stop → t4g.small →
  start (+$6.7).
- **Provisioning/deploys = Ansible** (decided 2026-07-19), CloudFormation/CLI only for
  cloud resources (VPC/SG, EC2+EIP, EBS×2, S3, KMS, SES, IAM role, SSM params). Ansible
  `infra/ansible/provision.yml` (packages, PGDG Postgres16+pgvector, /data mount, venv +
  systemd, Caddy, swap) + `deploy.yml` (sync backend/, pip install, `alembic upgrade head`,
  restart). Connection: SSH, port 22 SG-restricted to home IP (SSM plugin = fallback).
- Native services (systemd): **PostgreSQL 16 + pgvector** (PGDG apt) · **app** venv at
  `/opt/zoura`, single uvicorn worker · **Caddy** (apt, auto Let's Encrypt for
  `api-tbd.zoura.style`).
- **Storage split:** root EBS 10 GB (OS+code, never grows) · **data EBS 10 GB gp3 at
  `/data`** — Postgres only (`/data/postgres`); grows online, zero-downtime
  (`modify-volume` + `resize2fs`, grow-only, once/6 h, up to 16 TB). Nightly `pg_dump` → S3.
  **Photos stay on S3**, not EBS: ~4× cheaper/GB ($0.025 vs $0.092), auto-scales, 11-nines
  durable, and tbd then exercises the real prd `S3ImageStorage` path.
- **DNS/IPv4 (decision 2026-07-19): no Cloudflare.** Namecheap **A record →
  Elastic IP**, pay the $3.65/mo IPv4 fee (charged for holding ANY public IPv4 —
  CNAMEing to the EC2 public DNS name doesn't avoid it). No Route53 needed.
- Config: **SSM Parameter Store** (free) instead of Secrets Manager; instance role reads
  params and materializes `.env` at deploy. Role also scoped to KMS CMK + SES + S3 + CW.
- Deploy: rsync/upload `backend/` → SSM Run Command: venv pip install, `alembic upgrade
  head`, `systemctl restart zoura` (no SSH keys). Dockerfile kept for prd/ECS only.
- Trade-offs accepted: no auto-healing/scaling, brief redeploy blip, self-managed Postgres
  (data EBS + pg_dump; move to RDS later = DATABASE_URL change + dump/restore).
- Code prereqs: `KmsEnvelopeEncryptor` implementation (§3.4) — `affiliate` switch shipped
  2026-07-19.

### 3.2B — prd stack: ECS Fargate + ALB + RDS *(item 10b — target runbook, build at go-live)*

| Component | Service |
|---|---|
| Registry / compute / LB | ECR → ECS Fargate behind an ALB (TLS terminator, health check `/api/v1/health`) |
| Database | RDS for PostgreSQL 16 (`pgvector` available; single-AZ tbd, multi-AZ prd) |
| Secrets / encryption | Secrets Manager + a KMS CMK per env (measurement envelope encryption) |
| Email / storage / logs | SES · S3+CloudFront (images) · CloudWatch Logs (structlog JSON with `request_id`) |

1. [ ] Account prep: MFA on root, IAM admin role, CLI profile; default region `ca-central-1`
       everywhere — spot-check before every console action (wrong region = accidental PIPEDA
       violation). *(Largely done during tbd setup — verify, don't redo.)*
2. [ ] **prd VPC** (separate from tbd's): 2 private subnets (RDS) + 2 public (ALB) across 2 AZs;
       NAT gateway so tasks reach Anthropic / SES / Apple JWKS; SGs: ALB → task:8000,
       task → RDS:5432.
3. [ ] RDS PG16, DB `zoura_prd` (`db.t4g.medium`, **multi-AZ**); master creds auto-created in
       Secrets Manager; then connect once (bastion/SSM) and `CREATE EXTENSION IF NOT EXISTS vector;`.
4. [ ] KMS CMK `alias/zoura-prd-measurements` (separate from tbd's key); key policy: task role
       gets `kms:Encrypt/Decrypt/GenerateDataKey` only. Key ARN → `KMS_KEY_ID`.
5. [ ] SES: verify sending domain + `no-reply@` from-address → `SES_REGION`, `SES_FROM_ADDRESS`.
6. [ ] OAuth creds: Apple — native-app flow audience is the bundle ID `style.zoura.mobile`
       (a Service ID is only needed if a web flow is added) + `.p8` private key (record Team/Key
       IDs; `.p8` contents into Secrets Manager). Google — clients created 2026-07-17/18
       (Android + iOS + web); the backend needs only the web client ID as `GOOGLE_CLIENT_ID`
       (verification is JWKS-based); value is in dev `.env`.
6b. [ ] Stripe per mode — **sandbox settings don't carry to live**; redo at go-live: create the
        live product/prices (new `price_` IDs), the dashboard webhook endpoint
        (`https://api-<env>.zoura.style/api/v1/billing/webhook/stripe`, 3 events) with its own
        `whsec_`, portal configuration (card update + invoices ON, cancel + plan-switch OFF —
        in-app soft-cancel owns cancellation; done via API in sandbox 2026-07-18), statement
        descriptor (`ZOURA.STYLE`), and customer emails (receipts + failed payments) under
        Settings → Customer emails / Billing → Subscriptions and emails.
7. [ ] Secrets Manager: one JSON secret `zoura/prd/app` holding the full `.env` envelope —
       **fresh** `JWT_SECRET` (64-byte urlsafe; prd never shares dev/tbd keys), `DATABASE_URL`,
       `ANTHROPIC_API_KEY`, Apple/Google IDs, `SES_*`, `KMS_KEY_ID`, `AWS_REGION`,
       `PASSWORD_RESET_URL_TEMPLATE` (https App/Universal Link). `backend/.env.example` is the
       canonical key list — everything in it must be present in the secret. (tbd uses free SSM
       Parameter Store instead — §3.2A.)
8. [ ] ECR repo `zoura-backend` + lifecycle policy (keep last N tagged, expire untagged after
       7 days). *(ECR is prd-only; tbd deploys code via Ansible, no images.)*
9. [ ] `backend/Dockerfile` — `python:3.11-slim` + `build-essential libpq-dev`, copy
       `app/ alembic/ alembic.ini scripts/`, `EXPOSE 8000`, `ENTRYPOINT scripts/entrypoint.sh`
       which materializes `.env` from Secrets Manager (`get-secret-value` → JSON → `.env` lines)
       before exec-ing `uvicorn app.main:app --host 0.0.0.0 --port 8000` — per the .env policy
       (the image never ships secrets).
10. [ ] Two task definitions, same image: **`zoura-prd-app`** (long-running, CPU 512 /
        mem 1024; task role: `secretsmanager:GetSecretValue` on `zoura/prd/*` + KMS on the CMK +
        `ses:SendEmail`; container health check `curl -f localhost:8000/api/v1/health`) and
        **`zoura-prd-migrate`** (one-shot, CMD `alembic upgrade head`).
11. [ ] First migration via `aws ecs run-task --task-definition zoura-prd-migrate` — wait for exit 0
        (alembic output in CloudWatch). Then create the service: 2 desired tasks, ALB target group,
        deployment circuit breaker on, rolling min/max 100/200%.
12. [ ] Smoke test: `/api/v1/health` 200 · OAuth route returns **401 not 404** (mounted, unlike
        dev) · `forgot-password` → 202 / SES delivery · CloudWatch shows JSON logs with
        `request_id` (pretty colored logs ⇒ `ENVIRONMENT` isn't `prd`; fix before anything else).
13. [ ] DNS: `api.zoura.style` → ALB (Route53 alias if the zone moves there, else Namecheap
        CNAME); ACM cert `*.zoura.style` on the listener.
14. [ ] Record every provisioned ARN (RDS, KMS, ECR, ECS service, secret) in `infra/`.

### 3.3 CI + release flow *(tbd: Ansible; prd: lands with 3.2B)*
- [ ] CI on merge to master: `pytest` + `alembic upgrade head` against a throwaway Postgres →
      **tbd**: run `infra/ansible/deploy.yml` against the EC2 box. **prd** (once built):
      build/push `zoura-backend:prd-<git-sha>` to ECR → update both task definitions.
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
- Day-2 ops: prd `aws logs tail /ecs/zoura-prd --follow`; tbd `journalctl -u zoura` on the box /
  CloudWatch agent group · Logs Insights `filter request_id = "..."` · one-off SQL: tbd `psql` on
  the box, prd via SSM bastion only (never open RDS to the internet) · prd restart / new secrets:
  `update-service --force-new-deployment`; tbd: `systemctl restart zoura` via Ansible/SSM.

### 3.4 KMS envelope encryption *(item 11b)* — **required BEFORE the tbd deploy (§3.2A prereq)**
- [x] Real `KmsEnvelopeEncryptor` shipped 2026-07-19 (was `NotImplementedError`; dev keeps
      `LocalAesEncryptor`). Fresh KMS data key per encrypt (`GenerateDataKey` → AES-256-GCM);
      versioned blob `0x01 | len | wrapped-DEK | nonce | ct`; user id bound in both the KMS
      `EncryptionContext` and the GCM associated data (cross-user decrypt fails at either
      layer). DEK "rotation" = every re-submit wraps a new key; CMK rotation is KMS-native
      (old blobs decrypt via the old key version). 6 tests
      (`test_kms_envelope_encryptor.py`) with a fake KMS that really wraps/unwraps +
      enforces context; suite 344 green.

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
