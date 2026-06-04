# Settings mobile-wiring — plan & progress

Wire the existing Profile/Settings screens to the already-complete `SettingsService`
(`GET/PATCH /settings`, `GET /account/export`). Backend + `AppSettings` model + provider
already exist; screens are UI-only with `debugPrint`/local state. Scope = wiring only.

Theme + Units are **persist-only** this round (save the choice; do NOT yet build a dark
ThemeData or thread cm↔in conversion app-wide).

## Build order
1. **Notifications prefs** — load from `settingsProvider`, seed 9 toggles, PATCH each on change.
   Time/frequency pills + "send test" have no backend field → stay cosmetic.
2. **Appearance** — seed theme from `settings.theme`, PATCH `{theme}` on tap. Text size / accent /
   app-icon have no backend field → cosmetic (persist-only).
3. **Units** — `settings_screen` Units row → bottom sheet (Metric/Imperial), PATCH `{unit_system}`.
4. **Style preferences** — seed archetypes/palettes/occasions/intensity/formality from
   `style_preferences` blob; on Save PATCH `{style_preferences: {...}}` (store labels, not indices).
5. **Export My Data** — add `share_plus` (+`path_provider`); "Request" → `exportData()`; "download"/
   delivery tiles → share the JSON file via OS share sheet. Drop the fake progress timer.

## Pattern
Convert each `StatefulWidget` → `ConsumerStatefulWidget`; read `settingsProvider` (AsyncValue) and
seed local state once; write via `ref.read(settingsServiceProvider).updateSettings({...})` then
`ref.invalidate(settingsProvider)`. Mirror `delete_account_screen.dart` (existing wired example).

## Progress
- [x] 1. Notifications prefs — 9 toggles load/seed/persist optimistically (revert on error)
- [x] 2. Appearance (theme persist) — theme seeded + PATCHed; text/accent/icon stay cosmetic
- [x] 3. Units (persist) — Metric/Imperial bottom sheet → PATCH unit_system
- [x] 4. Style preferences (blob) — seed from + Save to style_preferences (stores labels)
- [x] 5. Export My Data (share_plus) — real GET /account/export → temp .json → OS share sheet
- [x] `flutter analyze` clean (whole project)

Provider note: `settingsProvider` made `.autoDispose` so each screen refetches fresh (no
shared cache to invalidate). Was previously unused, so no other consumers affected.
</content>
