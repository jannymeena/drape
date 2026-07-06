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

## Priority 1 — Analytics events *(needs: PostHog decision + project key — BE 2.5)*

- [ ] Add the analytics SDK (recommended: PostHog Flutter) + a thin
      `shared/services/analytics_service.dart` wrapper so event names live in one file.
- [ ] Instrument the doc-spec'd events, in this order of value:
      1. Onboarding funnel (`signup_*`, `onboarding_step_*`, `onboarding_completed`,
         `measurements_skipped`) — measures the docs' #1 success metric.
      2. Today engagement (`today_dashboard_viewed`, `outfit_logged`,
         `mix_and_match_*`, `regenerate`).
      3. Limit/conversion events (`usage_warning_shown`, `upgrade_tapped`,
         `paywall_viewed`) — needed to evaluate the paywall.
      4. Wardrobe + Shop events.

## Priority 2 — OAuth buttons [blocked: BE 2.1 + client IDs]

- [ ] `sign_up_screen.dart:101–102`, `login_screen.dart:114–115` — replace
      `debugPrint` with `sign_in_with_apple` / `google_sign_in`, send the ID token
      to the existing own-JWT signup/login endpoints.

## Priority 3 — Push notifications [blocked: BE 2.3 + FCM/APNS project]

- [ ] `firebase_messaging` + APNS entitlement + permission prompt (post-onboarding,
      not on first launch) + token registration + notification-tap deep routing.
- [ ] Today bell icon `today_dashboard_screen.dart` is a stub — either an
      in-app notification center (V2) or remove the bell until push lands.

## Priority 4 — Release prep *(last before launch)*

- [ ] End-to-end run-through on iOS + Android, fresh installs; iterate on regressions.
- [ ] Per-screen visual diff pass on iOS + Android.
- [ ] TestFlight + Play Console upload, store listings, version pinning.
- [ ] Privacy policy + PIPEDA disclosures (add the derived-measurements line when BE 1.1
      ships — see the BACKEND_CHANGES design note). **The app already links to
      `https://drape.app/privacy` and `https://drape.app/terms`** (privacy screen, via
      `url_launcher`) — those pages must be live before launch.
- [ ] Crash reporting decision (Sentry / Crashlytics) + wire-up.
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
