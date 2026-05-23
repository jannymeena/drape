/// Mirrors the backend `LogOutfitResponse` / `LogOutfitToast`
/// (`POST /outfits/{id}/log`). The toast is server-authored (message, colour,
/// duration, haptic) per CTO doc 2 §"TOAST PRIORITY LOGIC" — the client just
/// renders it, so milestone/streak copy stays owned by the backend.
library;

class LogOutfitToast {
  const LogOutfitToast({
    required this.type,
    required this.message,
    required this.durationMs,
    required this.background,
    required this.haptic,
  });

  final String type; // milestone | streak | default
  final String message;
  final int durationMs;
  final String background; // hex, e.g. "#6B4530"
  final String haptic; // success | warning | light

  factory LogOutfitToast.fromJson(Map<String, dynamic> json) => LogOutfitToast(
        type: json['type'] as String? ?? 'default',
        message: json['message'] as String? ?? 'Outfit logged!',
        durationMs: json['duration_ms'] as int? ?? 2000,
        background: json['background'] as String? ?? '#6B4530',
        haptic: json['haptic'] as String? ?? 'light',
      );
}

class LogOutfitResult {
  const LogOutfitResult({
    required this.outfitId,
    required this.loggedAt,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalOutfitsLogged,
    required this.toast,
  });

  final String outfitId;
  final DateTime loggedAt;
  final int currentStreak;
  final int longestStreak;
  final int totalOutfitsLogged;
  final LogOutfitToast toast;

  factory LogOutfitResult.fromJson(Map<String, dynamic> json) =>
      LogOutfitResult(
        outfitId: json['outfit_id'] as String,
        loggedAt: DateTime.parse(json['logged_at'] as String),
        currentStreak: json['current_streak'] as int? ?? 0,
        longestStreak: json['longest_streak'] as int? ?? 0,
        totalOutfitsLogged: json['total_outfits_logged'] as int? ?? 0,
        toast: LogOutfitToast.fromJson(json['toast'] as Map<String, dynamic>),
      );
}
