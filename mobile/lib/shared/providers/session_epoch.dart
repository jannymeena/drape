import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Monotonic counter identifying the current sign-in session.
/// [AuthController] bumps it on every session transition — login, signup,
/// logout, and a failed launch bootstrap — which rebuilds every provider that
/// `ref.watch`es it.
///
/// Contract: any provider that caches **user-scoped** state for the app's
/// lifetime (a non-autoDispose `FutureProvider` or a `StateNotifierProvider`)
/// must `ref.watch(sessionEpochProvider)` in its build callback, so a
/// register → logout → register cycle can never show the previous account's
/// data to the next one. autoDispose providers don't need it — they die with
/// their screens when the router bounces to Welcome.
final sessionEpochProvider = StateProvider<int>((_) => 0);
