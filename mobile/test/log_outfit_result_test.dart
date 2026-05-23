import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/log_outfit_result.dart';

/// Parses a representative `POST /outfits/{id}/log` payload (shape captured
/// live) so a backend field rename on the streak/toast contract is caught here.
void main() {
  test('LogOutfitResult parses streak counters + the server-authored toast', () {
    final result = LogOutfitResult.fromJson({
      'outfit_id': 'out-1',
      'logged_at': '2026-05-23T10:00:00Z',
      'current_streak': 5,
      'longest_streak': 9,
      'total_outfits_logged': 25,
      'toast': {
        'type': 'milestone',
        'message': "25 outfits logged! ✨ You're a Drape pro now.",
        'duration_ms': 3000,
        'background': '#8B9E6E',
        'haptic': 'success',
      },
    });

    expect(result.outfitId, 'out-1');
    expect(result.currentStreak, 5);
    expect(result.totalOutfitsLogged, 25);
    expect(result.toast.type, 'milestone');
    expect(result.toast.durationMs, 3000);
    expect(result.toast.background, '#8B9E6E');
  });

  test('toast falls back to sane defaults when fields are missing', () {
    final result = LogOutfitResult.fromJson({
      'outfit_id': 'out-2',
      'logged_at': '2026-05-23T10:00:00Z',
      'toast': <String, dynamic>{},
    });

    expect(result.currentStreak, 0);
    expect(result.toast.type, 'default');
    expect(result.toast.message, 'Outfit logged!');
    expect(result.toast.durationMs, 2000);
  });
}
