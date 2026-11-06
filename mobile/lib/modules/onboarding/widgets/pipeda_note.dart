import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'blueprint_scaffold.dart';

/// The one privacy line used across onboarding: a small lock and
/// "Compliant with Canadian PIPEDA privacy standards", centred, muted taupe.
/// Use it once per screen, at the foot of the content, and don't add other
/// "stored in Canada" lines next to it.
///
/// With [onTap] it becomes a link (e.g. to the privacy sheet).
class PipedaNote extends StatelessWidget {
  const PipedaNote({super.key, this.onTap});

  static const text = 'Compliant with Canadian PIPEDA privacy standards';

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.taupe.withValues(alpha: 0.8);
    final note = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 12, color: color),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: BlueprintText.optionSupport(context).copyWith(
              fontSize: 10,
              color: color,
              decoration: onTap == null ? null : TextDecoration.underline,
              decorationColor: color,
            ),
          ),
        ),
      ],
    );
    if (onTap == null) return note;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(padding: const EdgeInsets.all(8), child: note),
      ),
    );
  }
}
