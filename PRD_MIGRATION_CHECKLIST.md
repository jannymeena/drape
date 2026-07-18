# PRD Migration Checklist

Every small thing that must happen when Zoura goes live (`prd`), collected as they're
discovered during dev/tbd work. **Rule: any time a dev/tbd step has a "redo this for
live" shadow, it gets a line here immediately.** Items are grouped by system; tick at
go-live. Environment names follow the `dev` / `tbd` / `prd` convention; everything
targets AWS `ca-central-1` (PIPEDA).

---

## Domain & DNS (zoura.style)

- [ ] Route53: `api.zoura.style` (or `api-prd`) alias → prd ALB; ACM cert `*.zoura.style` on the listener.
- [ ] Host `https://zoura.style/privacy` and `/terms` — linked from the app (privacy screen), the Stripe portal config, and App Store review requires them live.
- [ ] `.well-known/apple-app-site-association` + `.well-known/assetlinks.json` on `zoura.style` when switching reset links from the `zoura://` custom scheme to https App/Universal Links.
- [ ] Mailboxes actually receiving: `privacy@zoura.style` (shown in-app as the privacy contact), `concierge@zoura.style` (Contact Us screen), `no-reply@` as sender. SES receiving or forwarding — decide and set up.

## Backend env (prd secret)

- [ ] Secrets Manager secret `drape/prd/app` materialized with every key in `backend/.env.example` — fresh `JWT_SECRET` (64-byte urlsafe), prd `DATABASE_URL`, `ANTHROPIC_API_KEY`, `KMS_KEY_ID`, `IMAGE_BUCKET`/`IMAGE_CDN_BASE_URL`, `SES_*`, live Stripe keys (below), `FCM_CREDENTIALS_JSON`, `APPLE_*`, `GOOGLE_CLIENT_ID`.
- [ ] `PASSWORD_RESET_URL_TEMPLATE` → https App/Universal Link form (not `zoura://`) once assetlinks/AASA are hosted.
- [ ] `STRIPE_PORTAL_RETURN_URL` → prd deep link / universal link.
- [ ] Sanitize pydantic `Settings` validation errors before prd — startup errors currently echo the input dict (Phase 7 hardening item).
- [ ] **Migrations: flip from squash-and-wipe to additive forward-only** the moment prd has real users (pre-prod convention ends here).

## SES (email)

- [ ] Verify `zoura.style` sending domain in prd's SES (`ca-central-1`) — DKIM/SPF records in Route53.
- [ ] Request **production access** (sandbox exit) — takes a day or two; kick off early.
- [ ] `SES_FROM_ADDRESS=no-reply@zoura.style`.

## Stripe — live mode (sandbox settings do NOT carry over)

- [ ] Activate the account: business verification + bank account for payouts.
- [ ] Recreate product/prices in live mode (new `price_...` IDs): Zoura Pro — $9.99 CAD/month, $79.99 CAD/year. Fix the "Annual (Save $30)" copy vs real $39.89 saving before launch (UI or price).
- [ ] Dashboard webhook endpoint `https://api.zoura.style/api/v1/billing/webhook/stripe`, events: `invoice.paid`, `invoice.payment_failed`, `customer.subscription.deleted`; its `whsec_` into the prd secret.
- [ ] Portal configuration (was done via API in sandbox 2026-07-18): payment-method update + invoice history ON; subscription cancel + plan switch OFF (in-app soft-cancel owns cancellation); privacy/terms URLs.
- [ ] Statement descriptor `ZOURA.STYLE` + support contact on Public details.
- [ ] Customer emails: receipts + refunds ON (Business → Customer emails); upcoming renewals ON, expiring cards ON, card-payment failures ON (Billing → Subscriptions and emails); trial/bank-debit OFF.
- [ ] Failed payments: Card payments → Smart Retries; if all retries fail → **cancel the subscription** (drives our `customer.subscription.deleted` handler); invoice → past-due.
- [ ] Disputed payments → **cancel the subscription** (no rebilling a disputer; keeps DB in sync via webhook).
- [ ] Prevent failed payments: upcoming renewal events 7 days (feeds the renewal-reminder email).
- [ ] Live `sk_live_` + price IDs + `whsec_` into the prd secret; never in the repo.
- [ ] Mobile real card entry must exist by now (`flutter_stripe` PaymentSheet) — the mock `tok_` form cannot attach real cards. Related: Stripe vs Apple IAP decision for iOS digital subscriptions (App Store guideline 3.1.1) — resolve before submission.

## Google / OAuth

- [ ] OAuth consent screen → publish to **production** (Google review if scopes require).
- [ ] Android OAuth client: add the **release** signing SHA-1 — with Play App Signing, that's Google's signing key fingerprint from Play Console → App integrity (the dev-machine debug SHA-1 stays for local builds).
- [ ] Web client ID (`GOOGLE_SERVER_CLIENT_ID`) unchanged — same value in the prd mobile define file and backend `GOOGLE_CLIENT_ID`.

## Apple (once Developer enrollment lands)

- [ ] App ID `style.zoura.mobile`: Sign in with Apple capability + Push Notifications capability; Xcode entitlements.
- [ ] Sign in with Apple `.p8` key → `APPLE_TEAM_ID`/`APPLE_KEY_ID`/key file into the prd secret; `APPLE_CLIENT_ID=style.zoura.mobile`.
- [ ] APNs auth key → upload to Firebase project settings (Cloud Messaging) for iOS push.
- [ ] Register the iOS app in Firebase → `GoogleService-Info.plist` into the Runner; widen `FeatureFlags.push` beyond Android.
- [ ] App Store: guideline 4.8 satisfied (Apple sign-in ships alongside Google ✓).

## Firebase / Push

- [ ] Decide: separate prd Firebase project vs the current `zoura-ec971` (separate keeps sandbox/prod push tokens and quotas apart; if separate → new `google-services.json`, new service-account JSON in the prd secret).
- [ ] Real-device end-to-end push test against the prd (or tbd) backend — dev logs instead of sending, so this has never run.

## Sentry

- [ ] `SENTRY_ENVIRONMENT=prd` in the release define file (project can stay shared; events separate by environment tag).
- [ ] Privacy policy lists Sentry as a processor — **US region** storage (org created in `ingest.us.sentry.io`).
- [ ] Alert rules (new-issue notification) before launch.

## PostHog

- [ ] Create a separate **prd project** (dev events must not pollute launch metrics) → its `phc_` key into the release define file (`POSTHOG_API_KEY`).
- [ ] Privacy policy lists PostHog as a processor — US cloud.

## Mobile release build

- [ ] Real Android release keystore (replace debug-signing TODO in `build.gradle.kts`) or Play App Signing; record SHA-1s (→ Google OAuth client above).
- [ ] Release `mobile/.env` materialized by CI from the secrets manager: `GOOGLE_SERVER_CLIENT_ID`, `SENTRY_DSN` + `SENTRY_ENVIRONMENT=prd`, prd `POSTHOG_API_KEY`; build with `--dart-define-from-file=.env`.
- [ ] API base URL for prd builds points at `https://api.zoura.style`.
- [ ] Store listing: privacy nutrition labels (data collected: email, measurements-encrypted, photos, coarse location, analytics) consistent with the privacy policy.

## Legal / privacy (PIPEDA)

- [ ] Privacy policy names all processors and locations: AWS `ca-central-1` (core data), Anthropic (AI), Stripe (payments, US), Sentry (crash, US), PostHog (analytics, US), Google/Apple (sign-in), Firebase (push).
- [ ] Privacy Officer contact (`privacy@zoura.style`) staffed/forwarded.

## Monitoring & ops

- [ ] CloudWatch alarms: 5xx rate, latency, DB connections; structlog JSON confirmed in prd (`ENVIRONMENT=prd`, not pretty logs).
- [ ] Stripe live webhook delivery monitoring (dashboard → Webhooks shows failures/retries) checked into the launch-week routine.
- [ ] `backend/logs/ai_usage.jsonl` equivalent for prd — decide where AI cost logging lands (CloudWatch).
