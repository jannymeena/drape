import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_service.dart';
import '../auth/models/current_user.dart';
import '../today/today_service.dart';
import '../wardrobe/image_pick.dart';

/// Talks to the backend `/users` endpoints that back the Profile tab. The
/// signed-in identity is read via `GET /users/me` (already hydrated at launch
/// by [AuthController.bootstrap]); profile edits go through
/// `PATCH /users/{id}`. Every [DioException] becomes a typed [ApiException];
/// the bearer is attached by the auth interceptor.
///
/// The backend `UserUpdate` persists `display_name`, `email`, `age_range`,
/// `location`, `gender`, and `phone`. Photo + styling chips are still UI-only.
class ProfileService {
  ProfileService(this._dio);

  final Dio _dio;

  /// `PATCH /users/{userId}` — updates the mutable identity fields. Only
  /// non-null arguments are sent (the backend uses `exclude_unset`, so an
  /// omitted field is left untouched). Returns the refreshed [CurrentUser].
  ///
  /// `email` is unique server-side but `update_user` does not pre-check it, so
  /// changing to an address already in use surfaces as a server error — the
  /// caller shows the [ApiException] message.
  Future<CurrentUser> updateProfile({
    required String userId,
    String? displayName,
    String? email,
    String? ageRange,
    String? location,
    String? gender,
    String? phone,
    bool? communityShareAvatar,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (displayName != null) body['display_name'] = displayName;
      if (email != null) body['email'] = email;
      if (ageRange != null) body['age_range'] = ageRange;
      if (location != null) body['location'] = location;
      if (gender != null) body['gender'] = gender;
      if (phone != null) body['phone'] = phone;
      if (communityShareAvatar != null) {
        body['community_share_avatar'] = communityShareAvatar;
      }
      final response = await _dio.patch<Map<String, dynamic>>(
        '/users/$userId',
        data: body,
      );
      return CurrentUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /profile/avatar/upload` — multipart upload of the user's chosen photo.
  /// Returns the refreshed [CurrentUser] (now carrying `avatarUrl`).
  Future<CurrentUser> uploadAvatar(PickedImage image) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          image.bytes,
          filename: image.filename,
          contentType: DioMediaType.parse(image.mimeType),
        ),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/profile/avatar/upload',
        data: form,
      );
      return CurrentUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ref.read(dioProvider));
});

/// The signed-in user's identity for Profile-tab screens. Returns the identity
/// [AuthController] already hydrated at launch ([AuthState.currentUser]); if it
/// isn't loaded yet (e.g. a fresh login this session, which doesn't refetch
/// `/users/me`), it fetches it. Because it watches [authControllerProvider], an
/// edit that calls [AuthController.applyCurrentUser] re-emits the new identity.
final currentUserProvider = FutureProvider<CurrentUser>((ref) async {
  final cached = ref.watch(authControllerProvider).currentUser;
  if (cached != null) return cached;
  return ref.read(authServiceProvider).fetchCurrentUser();
});

/// Whether the signed-in user is on the Pro tier. Sourced from
/// `GET /usage/current-week` (`subscription_tier`); best-effort — a failed
/// fetch defaults to free rather than blanking the header.
final profileIsProProvider = FutureProvider<bool>((ref) async {
  try {
    final usage = await ref.read(todayServiceProvider).getCurrentWeekUsage();
    return usage.isPro;
  } on ApiException {
    return false;
  }
});
