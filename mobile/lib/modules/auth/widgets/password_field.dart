import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_text_field.dart';

/// Password field with a 4-segment strength meter underneath.
/// Strength is computed by length + character variety; real validation lives in Phase E.
class PasswordField extends StatefulWidget {
  final TextEditingController? controller;
  final String label;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final bool showStrength;

  const PasswordField({
    super.key,
    this.controller,
    this.label = 'Password',
    this.errorText,
    this.onChanged,
    this.showStrength = true,
  });

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  int _strength = 0;

  void _onChanged(String value) {
    setState(() => _strength = _scoreOf(value));
    widget.onChanged?.call(value);
  }

  int _scoreOf(String s) {
    if (s.isEmpty) return 0;
    var score = 0;
    if (s.length >= 4) score++;
    if (s.length >= 8) score++;
    if (RegExp(r'[A-Za-z]').hasMatch(s) && RegExp(r'\d').hasMatch(s)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(s) || s.length >= 12) score++;
    return score;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DrapeTextField(
          label: widget.label,
          controller: widget.controller,
          obscureText: true,
          errorText: widget.errorText,
          onChanged: _onChanged,
          textInputAction: TextInputAction.done,
        ),
        if (widget.showStrength) ...[
          const SizedBox(height: 8),
          _StrengthMeter(score: _strength),
        ],
      ],
    );
  }
}

class _StrengthMeter extends StatelessWidget {
  final int score;
  const _StrengthMeter({required this.score});

  @override
  Widget build(BuildContext context) {
    final fill = switch (score) {
      0 => AppColors.taupeSoft,
      1 => AppColors.error,
      2 => AppColors.gold,
      _ => AppColors.sage,
    };
    return Row(
      children: List.generate(4, (i) {
        final filled = i < score;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < 3 ? 6 : 0),
            height: 4,
            decoration: BoxDecoration(
              color: filled ? fill : AppColors.taupeSoft.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      }),
    );
  }
}
