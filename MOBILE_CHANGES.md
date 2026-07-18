# DRAPE — Mobile Changes (Pending Tasks)

**Created:** 2026-07-05 · derived from the gap analysis of `CTO_Handoff_*.md` vs the codebase;
completed work removed — record in git history.
**Updated:** 2026-07-07 · the former P1 (`ctohandoff_gap`) and P2 (small leftovers & dead
controls) shipped in full and are removed; the remaining priorities renumbered P1–P5.
Decisions made along the way are in Notes.
Companion doc: `BACKEND_CHANGES.md` (referenced below as "BE …").
Conventions: module-wise folders (`modules/<feature>/` + `shared/`), all routes in
`shared/providers/router_provider.dart`, one-by-one AI calls with per-success state updates.

Legend: **[blocked: …]** = needs backend work first; everything else is buildable now.

---

## Priority 1 — Analytics events *(instrumentation buildable now; PostHog key drops in later — BE 2.3)*

**Plan (2026-07-08)** — build everything against a local debug sink now; when the PostHog
project key arrives, add `posthog_flutter` + a `PosthogAnalyticsService` impl and select it
by key presence (`--dart-define=POSTHOG_API_KEY`). Same provider pattern as the backend:
interface + per-env impl, dev logs.

- [x] Wrapper (`shared/services/analytics/`) — shipped 2026-07-08:
      `analytics_events.dart` — every event name as a constant, one file;
      `analytics_service.dart` — abstract `AnalyticsService` (`capture`, `identify`, `reset`)
      + `DebugAnalyticsService` (dart:developer log sink);
      `shared/providers/analytics_provider.dart` — Riverpod wiring.
      `identify(userId)` on login/signup/bootstrap, `reset()` on logout (AuthController).
- [x] Instrument the doc-spec'd events (~55 client-side) — shipped 2026-07-08, all four
      groups; still to exercise on-device (watch `analytics:` console lines):
      1. Onboarding funnel (`app_launched`, `welcome_*`, `signup_*`, `login_completed`,
         step selections, `measurement_step_completed`, `measurements_skipped`,
         `onboarding_completed`) — measures the docs' #1 success metric.
      2. Today engagement (`today_dashboard_viewed`, `outfit_logged` (spec:
         `item_logged_as_worn`), `mix_and_match_*`, `outfit_regenerated` (no spec'd name),
         `ai_reasoning_viewed`, history + starter/resume banners).
      3. Limit/conversion (`usage_limit_warning_shown`, `usage_limit_reached`,
         `upgrade_tapped`, paywall viewed, `pro_tease_shown`) — needed to evaluate the paywall.
      4. Wardrobe (`scanner_*`, add flow, item CRUD, limit modal) + Shop
         (`ai_style_advisor_*`, `buy_dont_buy_*`, `measurement_modal_shown`).
      Excluded: server-side events (`push_notification_sent`, `starter_wardrobe_assigned/
      deactivated`), obsolete `avatar_*` (avatar removal note), `first_outfit_generated`
      (client can't know "first" reliably — derive in PostHog from user's first
      `outfit_card_viewed` instead). Spec props trimmed to what the client already knows;
      no timing-derived props (`time_spent_seconds`) in v1.
- [x] PostHog sink shipped 2026-07-09 (`posthog_flutter` 5.30.0; analyze + full suite green):
      `shared/services/analytics/posthog_analytics_service.dart` — `PosthogAnalyticsService`
      implementing `AnalyticsService`; forwards `capture`/`identify`/`reset` to the `Posthog()`
      singleton, strips null props (PostHog rejects null values), `debug=kDebugMode`, relies on
      the SDK's PIPEDA-safe defaults (`personProfiles: identifiedOnly`, `sessionReplay: false`);
      `static ensureInitialized()` inits the native SDK in `main` before `runApp`, no-op when no
      key. Selection by key presence in `analytics_provider.dart`
      (`--dart-define=POSTHOG_API_KEY`, optional `POSTHOG_HOST`); keyless builds (dev/tests/
      release) keep `DebugAnalyticsService`. Native SDK is Dart-initialised, so **no
      Android/iOS manifest wiring yet** — deferred to release prep. `analytics_service_test.dart`
      covers the keyless fallback.
- [ ] When the real key arrives: pass `POSTHOG_API_KEY` (+ `POSTHOG_HOST` if not US cloud) to a
      device build, add the native manifest meta-data if we later want auto-init, and verify
      events land in the PostHog live view. Still to exercise the ~55 events on-device.

## Priority 2 — OAuth buttons *(backend shipped 2026-07-07; buildable now behind a flag — only client IDs still pending)*

**Plan (2026-07-09)** — build the full client flow now behind a feature switch that mirrors the
backend's `DISABLED_FEATURES` (`apple_login`, `google_login` — same names), plus key-presence
gating like the P1 analytics plan: Google needs `--dart-define=GOOGLE_SERVER_CLIENT_ID` to
function, so its absence hides the button; Apple is iOS-only and needs no client key, so it
shows unless `--dart-define=DISABLED_FEATURES=apple_login`. Hidden buttons hide the divider too
(no dead controls). The backend treats OAuth signup and login as the same idempotent
get-or-create, so both screens share one flow and route on `next_step` (resume-aware), not
straight to step 1.

- [x] Shipped 2026-07-09 (`google_sign_in` 7.2, `sign_in_with_apple` 8.1; analyze + tests +
      Android/iOS debug builds green):
      `shared/config/feature_flags.dart` — `FeatureFlags.appleLogin` / `.googleLogin`;
      `modules/auth/oauth_signin_service.dart` — native flows returning the provider ID token,
      null on user-cancel, typed `OAuthSignInException` otherwise;
      `AuthService.signupWithOAuth/loginWithOAuth` + `AuthController` counterparts with the
      same persistence + analytics (`method: apple|google`) as email;
      both screens wired (OAuth success routes via `loadAndHydrate` on both — an OAuth
      "signup" can be a returning user); `OAuthButtons` reads the flags;
      `test/auth_oauth_test.dart` covers the wire shape + flag-off collapse.
- [ ] When the client IDs arrive: pass `GOOGLE_SERVER_CLIENT_ID` (must equal one of the
      backend's `GOOGLE_CLIENT_ID` audiences); iOS Google config (`GIDClientID` + reversed
      client-ID URL scheme in `Info.plist`); Apple: Sign in with Apple capability/entitlement
      on the Runner target (Apple Developer setup — release prep); verify end-to-end against
      tbd. Until the entitlement exists, dev iOS builds should run with
      `--dart-define=DISABLED_FEATURES=apple_login` (the button works only once the
      capability is added).

## Priority 3 — Push notifications *(Android leg unblocked 2026-07-18: Firebase project `zoura-ec971`, `google-services.json` banked, backend FCM credential verified live)*

**Plan (V1 = Android; iOS joins after the Apple Developer / APNs key):**

- [x] Deps + build wiring: `firebase_core` + `firebase_messaging`;
      `com.google.gms.google-services` Gradle plugin (activates the banked
      `google-services.json`); `POST_NOTIFICATIONS` in the manifest.
- [x] `FeatureFlags.push` — Android-only gate + `push` joins the known
      `DISABLED_FEATURES` names (mirrors the backend switch).
- [x] `PushRegistrar` provider pair (`shared/services/push/`): no-op impl for
      non-Android/tests, FCM impl owning the whole token lifecycle —
      `getToken` → `POST /devices` on session start, `onTokenRefresh`
      re-register, `DELETE /devices/{token}` on logout. Best-effort
      throughout: push must never break auth flows.
- [x] Permission prompt **post-onboarding, not first launch**: registration is
      silent (token needs no permission); the one-time OS prompt fires on the
      Today dashboard (first post-onboarding screen), remembered via prefs.
- [x] Notification-tap deep routing: backend sends `data.route` literals
      (`paywall` today) → route-name map → `goNamed`, unknown routes no-op.
      Cold-start taps via `getInitialMessage`, background via
      `onMessageOpenedApp`. Foreground messages: analytics only in V1 (no
      local-notification display; the in-app UI already shows the same state).
- [x] Analytics: `push_permission_result`, `push_notification_tapped`,
      `push_foreground_received`.
- [x] Verify: analyze + tests (136) + debug APK green — google-services task
      runs, merged manifest carries `POST_NOTIFICATIONS` + the Firebase
      components. *(Pending: real-device E2E — needs a tbd backend or a
      manual FCM console send, since the dev backend logs instead of
      delivering.)*

**Still blocked / deferred:**

- [ ] iOS leg: APNs `.p8` into Firebase, `GoogleService-Info.plist`, Push
      Notifications entitlement + background mode (needs Apple Developer).
- [ ] Today bell icon `today_dashboard_screen.dart` is a stub — either an
      in-app notification center (V2) or remove the bell until push lands.

## Priority 4 — Release prep *(last before launch)*

- [ ] End-to-end run-through on iOS + Android, fresh installs; iterate on regressions.
- [ ] Real card entry: `payment_methods_screen.dart` fabricates `tok_<number>`
      tokens (mock-provider era) — invalid against real Stripe. Needs client-side
      tokenization (`flutter_stripe` PaymentSheet or equivalent) before live mode;
      sandbox testing meanwhile attaches Stripe test payment methods
      (`pm_card_visa`) via the API. Related open call: Stripe vs Apple IAP for iOS.
- [ ] Per-screen visual diff pass on iOS + Android.
- [ ] TestFlight + Play Console upload, store listings, version pinning.
- [ ] Privacy policy + PIPEDA disclosures (add the derived-measurements line when BE 1.1
      ships — see the BACKEND_CHANGES design note). **The app already links to
      `https://drape.app/privacy` and `https://drape.app/terms`** (privacy screen, via
      `url_launcher`) — those pages must be live before launch.
- [x] Crash reporting — **Sentry** chosen + wired 2026-07-09 (`sentry_flutter` 8.14.2; analyze +
      full suite green). Sentry over Crashlytics: no native-config wall (DSN-only, unlike the
      `google-services.json` Crashlytics needs — the same wall blocking P3), and PIPEDA-friendlier
      than shipping crash data to Google/Firebase (already rejected for auth).
      `shared/services/crash/crash_reporter.dart` — `CrashReporter` interface
      (`recordError`/`setUser`/`clearUser`) + `NoopCrashReporter`;
      `sentry_crash_reporter.dart` — `SentryCrashReporter` + `static runWithReporting()` that wraps
      `main`'s boot in Sentry's guarded zone (no-op passthrough without a DSN), `sendDefaultPii=false`,
      `tracesSampleRate=0` (crash-only), `environment` by build mode;
      selection by DSN presence in `crash_provider.dart` (`--dart-define=SENTRY_DSN`, optional
      `SENTRY_ENVIRONMENT`). `AuthController` sets/clears the Sentry user next to analytics
      identify/reset. `crash_reporter_test.dart` covers the keyless fallback.
      **Remaining:** create the Sentry project, pass `SENTRY_DSN` to a build, and confirm a test
      crash lands in the dashboard (needs the account — release prep).
- [ ] Reset-password deep link, prod path: App Links / Universal Links (the shipped `drape://`
      custom scheme is the dev path); the end-to-end device open has also not been exercised yet.
      The Email & Password screen's change-password flow rides this same reset-link path.

## Priority 5 — Post-launch / re-evaluate

- [ ] Dark `ThemeData` + the `profile_complete_dark_mode` mockup (the Appearance row is removed
      from Settings; screen + route kept, unreachable).
- [ ] Support attachments: `POST /support/*` has no attachment field. The Contact Us attach
      control was removed on that basis (2026-07-07); `report_bug_screen.dart:374`'s screenshot
      tile is the one remaining dead control — build BE attachment support or remove it too.
- [ ] Offline cache via `drift` (wardrobe) — re-evaluate if perf demands.
- [ ] OpenAPI codegen for the client — hand-written DTOs for now; revisit if it becomes the
      bottleneck.

---

## 📝 Notes (not tasks)

**Avatar — the 2D avatar is confirmed for removal (2026-07-06); do NOT build avatar features.**
No new avatar UI work, no avatar-reveal polish, no avatar-share features — the Onboarding
handoff's parametric avatar reveal (600×800 render, stats cards, Instagram story share) is
obsolete. The app's current photo-upload avatar (`avatar_reveal` photo-pick step, Edit Profile
"Change Photo") stays as-is until the removal work is scoped. When it is: drop the
`avatar_reveal` step and design/build a replacement onboarding completion step (no mockup
exists); decide with the backend whether "Change Photo" is removed or re-purposed as the
optional **style photo** (the body/skin-analysis personalization link — see the BACKEND_CHANGES
avatar note); then sweep routes, providers, and reveal/share strings.

**Decisions 2026-07-07 (dead-control cleanup, approved):** the privacy screen's 2FA switch and
Connected Apps (Google Calendar / Instagram revoke) sections were **removed** — 2FA is cut for
v1 and no app integrations exist (this also closed the backend settings-privacy follow-on —
the old BE 1.3 — with no backend work); "Correct Your
Data" routes to Contact Us with a preselected *Privacy & My Data* subject; policy links open
`https://drape.app/privacy` / `/terms` via `url_launcher`. The Email & Password screen dropped
its mocked 2FA card and fabricated session list; change email = immediate `PATCH /users/{id}`
(no verification round-trip in v1), change password = the forgot-password reset-link flow.
Contact Us: subject dropdown is real and submitted, optional reply-to rides `extra`,
"Send Email" opens `mailto:`, and the attach control was removed (no backend attachment field
— see P5).

**Measurement step order** differs from the handoff doc (doc: shoulders is step 3;
app: shoulders is step 8, see `resume_route_map.dart`). Deliberate/harmless — but
the doc's `measurements_step_N` ids don't map 1:1; the backend `_NEXT` map is the
source of truth.

**Handoff-mockup collapse/deviation decisions (matched, no action):** the two compare-plans
and two FAQ design variants intentionally collapse into one screen each; the export-history
variant is merged into the export screen (commented in code); the 4 `measurement_guide_*_locked`
mockups are superseded by the accepted CustomPaint figures; the dedicated wardrobe hard-block
full-screens are deliberately covered by the blocked-level banner + paywall instead;
`warm_mocha_editorial` (in every design folder) is the theme reference, not a screen. The 12
loose screenshots at the tab-folder roots were classified 2026-07-07: all are Figma board
overviews duplicating named mockups — renamed to `_board_*_overview.png`, nothing unique.

**App screens with no design (reverse gap):** `forgot_password_screen`,
`reset_password_screen` (never got mockups), `billing_history_screen` (built from the
Profile handoff §API instead). `wardrobe_setup_screen.dart` optional flow is an addition,
not a gap — keep. `avatar_reveal_screen` is covered by the Avatar note above.
