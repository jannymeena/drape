import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../shared/config/feature_flags.dart';

/// The OAuth provider kinds the backend accepts as `auth_method`
/// (`apple_id_token` / `google_id_token` payload fields). [name] is the wire
/// literal.
enum OAuthProvider { apple, google }

/// A native OAuth flow failed for a reason other than the user backing out.
/// [message] is user-facing (shown as the screen's inline error).
class OAuthSignInException implements Exception {
  const OAuthSignInException(this.message);

  final String message;

  @override
  String toString() => 'OAuthSignInException: $message';
}

/// Runs the platform sign-in sheets and returns the provider's identity token
/// for the backend to verify (`RealOAuthVerifier`). Returns null when the user
/// cancels the sheet — callers treat that as a no-op, not an error.
class OAuthSignInService {
  bool _googleInitialized = false;

  Future<String?> idTokenFor(OAuthProvider provider) {
    return switch (provider) {
      OAuthProvider.apple => _appleIdToken(),
      OAuthProvider.google => _googleIdToken(),
    };
  }

  Future<String?> _appleIdToken() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = credential.identityToken;
      if (token == null) {
        // Vanishingly rare (a malformed authorization); surface like any
        // other provider failure.
        throw const OAuthSignInException(
          'Apple sign-in failed. Please try again.',
        );
      }
      return token;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw const OAuthSignInException(
        'Apple sign-in failed. Please try again.',
      );
    }
  }

  Future<String?> _googleIdToken() async {
    final signIn = GoogleSignIn.instance;
    try {
      if (!_googleInitialized) {
        await signIn.initialize(
          serverClientId: FeatureFlags.googleServerClientId,
        );
        _googleInitialized = true;
      }
      final account = await signIn.authenticate();
      final token = account.authentication.idToken;
      if (token == null) {
        throw const OAuthSignInException(
          'Google sign-in failed. Please try again.',
        );
      }
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw const OAuthSignInException(
        'Google sign-in failed. Please try again.',
      );
    }
  }
}

final oauthSignInServiceProvider = Provider<OAuthSignInService>((ref) {
  return OAuthSignInService();
});
