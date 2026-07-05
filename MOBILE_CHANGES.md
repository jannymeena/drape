# DRAPE — Mobile Changes (Gap Closure Plan)

**Created:** 2026-07-05 · derived from the gap analysis of `CTO_Handoff_*.md` vs the codebase.
**Updated:** 2026-07-05 · added the `screens/` design-folder audit (~120 Stitch mockups vs app).
Companion doc: `BACKEND_CHANGES.md` (its priority numbers are referenced below as "BE Pn").
Conventions: module-wise folders (`modules/<feature>/` + `shared/`), all routes in
`shared/providers/router_provider.dart`, one-by-one AI calls with per-success state updates.

Legend: **[blocked: …]** = needs backend work first; everything else is buildable now.

---

## 🎨 Design audit A — Designs with no app counterpart (MOST IMPORTANT)

From `screens/<tab>/…` mockups that have **no implementation at all**:

- [x] **Favorites view (Wardrobe)** ✅ **Done 2026-07-05** — "Favorites" chip
      (first in the single-select filter row) drives the server-side
      `is_favorite` filter; designed empty state built
      (`widgets/wardrobe_empty_state.dart` → `FavoritesEmptyState`);
      un-starring inside the view removes the item after server confirm.
      Covered by `wardrobe_controller_test.dart` (+3) and
      `wardrobe_empty_state_test.dart`. *Skipped:* the mockup's "Style
      inspiration → Atelier collection" card at the bottom — it routes to the
      Shop feed, which is still static (P2); add it when Shop is wired.
      *(Remaining related stub: Shop advisor favorites,
      `ai_advisor_initial_screen.dart:136`.)*
- [x] **Wardrobe empty state (0 items)** ✅ **Done 2026-07-05** — replaced the
      generic message + grow card with the designed state
      (`wardrobe_empty_state` mockup): hanger circle, "Your digital wardrobe
      awaits", 3 benefit rows, "+ Add Your First Item" CTA (opens the add
      sheet). Shown only for All Pieces + no search; per-category empties keep
      the lighter message. *The mockup's starter-progress banner ("0/10 items
      to unlock real wardrobe mode") is the starter-indicator task below —
      still [blocked: BE P4].*
- [x] **Starter-wardrobe indicator banner (Wardrobe grid)** ✅ **Done 2026-07-05**
      — `StarterWardrobeBanner` with X/10 progress toward real-wardrobe mode;
      shown while starter items remain and real items < 10.
- [x] **Today resume banner** ✅ — built 2026-07-05; see **P3**.
- ~~**Dark-mode variant**~~ — design `profile_complete_dark_mode`. *(Decision
      2026-07-05: dark mode deferred for v1 — hide the appearance toggle instead;
      see **P8**.)*

## 🎨 Design audit B — Present but deviating from the designs (SECOND)

Implemented screens whose look/behavior differs from the mockup:

- [x] **Measurement guides** (`measurement_guide_chest/waist/hips/inseam_locked`,
      4 designs): *(Decision 2026-07-05: CustomPaint figures accepted as final —
      the 4 mockups are superseded; no restyle.)*
- [x] **Success toasts** ✅ **Done 2026-07-05** — `shared/widgets/drape_toast.dart`
      (`showDrapeToast`: floating sage pill, icon + bold message + optional
      trailing detail). Swept: wardrobe add/edit/photo/remove/log-worn,
      mix & match swap, measurements saved, profile updated, contact-us sent,
      wishlist (delegates). Today's server-authored log toast keeps server
      colour/duration in the shared shape. Errors stay plain SnackBars.
      *Nice-to-have left open:* the mockup's trailing "27/30 items" capacity
      detail on the add-item toast.
- [x] **Wardrobe capacity hard-block** ✅ **Done 2026-07-05 (with deviation)** —
      the banner/dialog CTAs now route to the live paywall. The mockups'
      dedicated full-screen hard-block variant is deliberately skipped: the
      blocked-level banner + paywall covers the flow with less surface.
- [x] **Shop tab (26 designs)** ✅ — wired live 2026-07-05; see **P2**.
- **Note (no task):** `step_3_shoulders` — measurement order deviates (shoulders is
  app step 8); accepted deviation, see Notes.

---

## Rest of the tasks

---

## Priority 1 — Paywall & billing wiring ✅ **Done 2026-07-05**

The app enforces free-tier limits but every upgrade CTA is a `debugPrint` stub, so a
free user who hits a limit has no path forward.

- [x] **Paywall** = Compare Plans wired live: real prices from `/subscription`
      plans, upgrade/trial CTAs call the API, "You're on Pro" state, providers
      invalidated on success.
- [x] **All 8 stubbed upgrade entry points** now route to the paywall:
      - `today_dashboard_screen.dart:124` (limit dialog), `:374` (usage banner)
      - `wardrobe_screen.dart:201`, `:261` (capacity banner / add-item)
      - `manual_entry_screen.dart:328`
      - `intelligence_report_screen.dart:381` (Pro report upgrade card)
      - Buy/Don't-Buy: `buy_dont_buy_scan_screen.dart:435`,
        `buy_dont_buy_limit_reached_screen.dart:103`
- [x] **Billing screens → real data** (subscription mgmt with free/pro/ending
      states; 3-step cancel: reason → soft cancel → retention accept/decline;
      history + payment methods live; download/CVV stubs removed): `subscription_management_screen.dart`,
      `payment_methods_screen.dart`, `billing_history_screen.dart` (incl. export/
      download stubs at `:65`/`:149`), `retention_offer_screen.dart:48`,
      cancellation flow (`cancellation_reason_sheet.dart` →
      `final_cancellation_confirmation_screen.dart`) — all currently static/
      `debugPrint`. Add a `billing_service.dart` + controller.

## Priority 2 — Shop tab wiring ✅ **Done 2026-07-05**

All shop screens are static mockups. Build `modules/shop/shop_service.dart` +
controllers, then replace the hardcoded data per screen:

- [x] **Shop feed:** ✅ `shop_feed_screen.dart:28` (`const _products`) → `GET /shop/feed`;
      real loading/empty states (screens exist); measurement-gate via the feed flag
      (banner/modal widgets already exist: `measurement_incomplete_banner.dart`,
      `measurement_required_modal.dart`).
- [x] **Gap analysis:** ✅ (top-gap headline + category-filtered products + Pro teaser → paywall) `gap_analysis_screen.dart:24` → `GET /shop/gap-analysis`;
      Pro tease for free tier (Trigger 4).
- [x] **AI Style Advisor:** ✅ (live chat, one ask per turn, catalog-matched suggestions, history resume) `ai_advisor_conversation_screen.dart:15,21`,
      `ai_advisor_initial_screen.dart:14,16`, `ai_advisor_history_screen.dart:15`
      → advisor ask/history endpoints; fire questions one-by-one, render each reply
      as it lands. Dead buttons: `ai_advisor_conversation_screen.dart:276`
      ("view all 3 items"), `ai_advisor_initial_screen.dart:136` (favorites).
- [x] **Buy/Don't-Buy:** ✅ (photo → verdict with real reasons via router extra; 429 → limit screen; recent checks live) wire scan → `POST /shop/buy-check` → verdict screens;
      usage banner from the 5/week counter. Dead buttons:
      `buy_dont_buy_verdict_dont_buy_screen.dart:146` (alternatives), `:156`
      (buy anyway), `buy_dont_buy_limit_reached_screen.dart:140` (purchase history).
- [x] **Wishlist:** ✅ (persisted, price-drop badges) `wishlist_screen.dart:18` (local `setState` list) → persist via
      wishlist endpoints.
- [x] **In-app browser:** ✅ cart/reload stubs cut for v1 `in_app_browser_screen.dart:192` (add to cart), `:284`
      (reload) — implement or remove for v1.
- [x] `shop_feed_empty_screen.dart` ✅ routes to Edit Measurements ("complete profile") → route to the next
      incomplete measurement step (same target as the P3 resume banner).

## Priority 3 — Today tab: resume banner + starter banner + occasion chips

- [x] **Resume banner** ✅ **Done 2026-07-05** — gold progress banner
      (`widgets/resume_banner.dart`) below the occasion chips; shows
      "X of 8 steps done" computed client-side from `GET /profile/measurements`
      (the frame's `incomplete_profile` flag tracks *onboarding*, not
      measurements — see BE P5). Hides once all 7 required are saved (weight is
      optional — no nagging for it). Kept fresh via provider invalidation on
      pull-to-refresh and after a save in the measurements editor. Covered by
      3 new cases in `today_dashboard_screen_test.dart`.
      *Deviations from the doc:* tap routes to the **Edit Measurements screen**
      (single prefilled form) rather than deep-linking into the onboarding
      measurement-step screens — simpler post-onboarding and avoids re-entering
      the flow; and the banner is computed on-device until BE P5 lands.
- [x] **Starter-wardrobe banner (Today)** ✅ **Done 2026-07-05** — rendered from
      the backend flag; "I'll do this later" persists via
      `POST /today/banners/starter_wardrobe/dismiss` (7-day window).
- [x] **Occasion chips filter** ✅ **Done 2026-07-05** — chips are now
      `All / Work / Casual / Gym / Date Night` ("All" default; dropped "Lounge",
      which the backend never generates) and filter the outfit cards, pending
      skeletons, and retry cards by the backend occasion literal. Filtering to
      an occasion with no pick shows a "No X pick in today's outfits" message.
      Covered by 3 new cases in `today_dashboard_screen_test.dart`.
      *Follow-up (still open):* per-occasion **generation** from the chip —
      pairs naturally with BE P4/generation work.

## Priority 4 — Profile intelligence stats ✅ **Done 2026-07-05**

- [x] ✅ Stat grid wired to `GET /profile/intelligence` (placeholders while
      loading; fake numbers gone). Original finding: hardcoded stats
      (`34%`, `$4.20`, `23`, `$4,200`) — users see fake numbers on their own
      profile. Wire `_StatGrid` to `GET /profile/intelligence` with loading/error
      states; hide the grid rather than show placeholders if the call fails.

## Priority 5 — Analytics events — **DEFERRED** (decision 2026-07-05)

*Analytics postponed for now; accept that launch metrics from the handoff docs
won't be measurable until this is revisited. Tasks kept below for when it is.*

- [ ] Add the analytics SDK (recommended: PostHog Flutter — pending the decision
      in BE doc §Analytics) + a thin `shared/services/analytics_service.dart`
      wrapper so event names live in one file.
- [ ] Instrument the doc-spec'd events, in this order of value:
      1. Onboarding funnel (`signup_*`, `onboarding_step_*`, `onboarding_completed`,
         `measurements_skipped`) — measures the docs' #1 success metric.
      2. Today engagement (`today_dashboard_viewed`, `outfit_logged`,
         `mix_and_match_*`, `regenerate`).
      3. Limit/conversion events (`usage_warning_shown`, `upgrade_tapped`,
         `paywall_viewed`) — needed to evaluate P1.
      4. Wardrobe + Shop events as those flows get wired.

## Priority 6 — OAuth buttons [blocked: BE P6 + client IDs]

- [ ] `sign_up_screen.dart:101–102`, `login_screen.dart:114–115` — replace
      `debugPrint` with `sign_in_with_apple` / `google_sign_in`, send the ID token
      to the existing own-JWT signup/login endpoints.

## Priority 7 — Push notifications [blocked: BE P7 + FCM/APNS project]

- [ ] `firebase_messaging` + APNS entitlement + permission prompt (post-onboarding,
      not on first launch) + token registration + notification-tap deep routing.
- [ ] Today bell icon `today_dashboard_screen.dart:512` is a stub — either an
      in-app notification center (V2) or remove the bell until push lands.

## Priority 8 — Settings that persist but don't apply

- [x] **Dark theme** ✅ **Done 2026-07-05** — Appearance row removed from
      Settings (screen + route kept, unreachable). Dark `ThemeData` stays post-v1.
- [x] **Units (cm↔in)** ✅ **Done 2026-07-05** — new `shared/units.dart` holds the
      canonical factors (used by onboarding input + edit-measurements); the
      Edit Measurements unit toggle now defaults from the app-wide Units
      setting (falls back to the draft's stored hint). Measurements remain the
      only unit-bearing display outside onboarding.

## Priority 9 — Small dead controls (sweep)

- [x] **Sweep** ✅ **Done 2026-07-05** — removed: account Phone row + Connected
      Accounts section (return with 2FA / OAuth 11a), feature-request Upload
      Concept tile, SEND TEST NOTIFICATION (returns with P7), help-center
      Popular Guides. Bonus: account email row now shows the real user email
      (was hardcoded `alex.chen@email.com`). Upvote stays [blocked: BE P8].
- [x] **Reset-password deep link** ✅ **Done 2026-07-05** — `drape://` custom
      scheme configured (AndroidManifest intent-filter + `flutter_deeplinking_
      enabled`; iOS `CFBundleURLTypes` + `FlutterDeepLinkingEnabled`). Link
      shape: `drape://drape.app/auth/reset-password?token=…`. Verified: debug
      APK builds, plist lints; **end-to-end device open not yet exercised**.
      Backend `.env` needs `PASSWORD_RESET_URL_TEMPLATE` set to that shape
      (noted in BACKEND_CHANGES). App Links / Universal Links = prod follow-up.
- [x] Feature-request upvote ✅ **Done 2026-07-05** — Popular Features is the
      public board (`GET /support/feature-requests`); upvote toggles via the
      votes API.
- [ ] Remaining stubs found during the sweep (not in the original list):
      `privacy_data_screen.dart` revoke gcal/ig + correct-data + policy links
      (rows have no backend — 8c follow-on), `email_password_settings_screen.dart`
      change email/password actions, `contact_us_screen.dart:111` attach.

## Priority 10 — Release prep *(absorbed from `PROJECT_STATUS.md` §6, 2026-07-06)*

- [ ] End-to-end run-through on iOS + Android, fresh installs; iterate on regressions.
- [ ] Per-screen visual diff pass on iOS + Android.
- [ ] TestFlight + Play Console upload, store listings, version pinning.
- [ ] Privacy policy + PIPEDA disclosures (add the derived-measurements line when the backend's
      §5.5.1 consent path ships — see the BACKEND_CHANGES design note).
- [ ] Crash reporting decision (Sentry / Crashlytics) + wire-up.

## Parking lot / deferred *(absorbed from `PROJECT_STATUS.md` §7, 2026-07-06)*

- Offline cache via `drift` (wardrobe) — re-evaluate post-launch if perf demands.
- OpenAPI codegen for the client — hand-written DTOs for now; revisit if it becomes the bottleneck.
- Reasoning-detail + history sheets still show the plain icon (their payloads lack category/colour) —
  minor `GarmentPlaceholder` follow-up.
- Dark `ThemeData` (P8) — post-v1.

---

## 📝 Notes (not tasks)

**Avatar — 2D avatar is being removed; do NOT build against the handoff doc.**
The Onboarding handoff's parametric avatar reveal (600×800 render, stats cards,
Instagram story share of the avatar) is obsolete. The app's current photo-upload
avatar (`avatar_reveal` photo-pick step, Edit Profile "Change Photo") stays as-is
until the removal decision is finalized — no new avatar UI work, no avatar-reveal
polish, no avatar-share features. When removal lands, the onboarding flow gets a
new completion step design; scope that then. (Backend implications, incl. keeping
the body-analysis personalization link, are noted in `BACKEND_CHANGES.md`.)

**Measurement step order** differs from the handoff doc (doc: shoulders is step 3;
app: shoulders is step 8, see `resume_route_map.dart`). Deliberate/harmless — but
the doc's `measurements_step_N` ids don't map 1:1; the backend `_NEXT` map is the
source of truth.

**Design-audit leftovers (matched cleanly, no action):** all onboarding screens
incl. `lifestyle_occasions_profile` (designed in `screens/`, just absent from the
handoff markdown), the three outfit-logged toast states (server-authored),
usage warnings 75/90/100, Today loading/empty/error states, and all Profile
screens — the two compare-plans and two FAQ design variants intentionally
collapse into one screen each; the export-history variant is merged into the
export screen (commented in code). `warm_mocha_editorial` (in every design
folder) is the theme reference, not a screen.

**App screens with no design (reverse gap):** `avatar_reveal` (photo-pick),
`forgot_password_screen`, `reset_password_screen`. No avatar-reveal design exists
at all — consistent with the 2D-avatar removal (see Avatar note above); the two
password screens just never got mockups. `wardrobe_setup_screen.dart` optional
flow is an addition, not a gap — keep.
