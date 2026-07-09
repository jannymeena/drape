# Drape — mobile

Flutter client for Drape. All setup, run, and test instructions live in the
[root README](../README.md); open tasks live in [`MOBILE_CHANGES.md`](../MOBILE_CHANGES.md).

```bash
flutter run                        # backend must be running — see root README
flutter analyze && flutter test
```

## Feature flags

No `.env` — flags are baked in at build time via `--dart-define`
(see `lib/shared/config/feature_flags.dart`). Names mirror the backend's
`DISABLED_FEATURES`.

```bash
# turn features OFF (comma-separated: apple_login, google_login)
flutter run --dart-define=DISABLED_FEATURES=apple_login,google_login

# Google sign-in is off until its client ID is provided (must match one of
# the backend's GOOGLE_CLIENT_ID audiences)
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=<id>.apps.googleusercontent.com
```

Defaults with no defines: Google hidden (no client ID), Apple shown on iOS
only. Until the Sign in with Apple capability is added to the Runner target,
run iOS dev builds with `--dart-define=DISABLED_FEATURES=apple_login`.
Several defines can be grouped in a JSON file: `--dart-define-from-file=dev.json`.
