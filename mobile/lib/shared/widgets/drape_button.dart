import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum DrapeButtonVariant { filled, outlined, text, apple, google }

class DrapeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final DrapeButtonVariant variant;
  final Widget? leading;
  final Widget? trailing;
  final bool fullWidth;
  final bool loading;

  /// Fully-rounded (stadium) shape instead of the default 14dp radius.
  final bool pill;

  /// Material elevation for a soft drop shadow (0 = flat, the default).
  final double elevation;

  /// Overrides the default label text style (defaults to `titleSmall`); the
  /// foreground color is always applied on top. Use for larger hero CTAs.
  final TextStyle? labelStyle;

  const DrapeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = DrapeButtonVariant.filled,
    this.leading,
    this.trailing,
    this.fullWidth = true,
    this.loading = false,
    this.pill = false,
    this.elevation = 0,
    this.labelStyle,
  });

  const DrapeButton.outlined({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.fullWidth = true,
    this.loading = false,
  }) : variant = DrapeButtonVariant.outlined,
       trailing = null,
       pill = false,
       elevation = 0,
       labelStyle = null;

  const DrapeButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.fullWidth = false,
    this.loading = false,
  }) : variant = DrapeButtonVariant.text,
       trailing = null,
       pill = false,
       elevation = 0,
       labelStyle = null;

  const DrapeButton.apple({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = true,
    this.loading = false,
    this.labelStyle,
  }) : variant = DrapeButtonVariant.apple,
       leading = const Icon(Icons.apple, color: AppColors.white, size: 20),
       trailing = null,
       pill = false,
       elevation = 0;

  const DrapeButton.google({
    super.key,
    required this.label,
    required this.onPressed,
    this.fullWidth = true,
    this.loading = false,
    this.labelStyle,
  }) : variant = DrapeButtonVariant.google,
       leading = const _GoogleLogo(),
       trailing = null,
       pill = false,
       elevation = 0;

  @override
  Widget build(BuildContext context) {
    // A null [onPressed] means the action isn't available — the button must
    // *look* unavailable too, not just ignore taps. Muting here covers every
    // call site that gates on a condition (unsaved form, in-flight submit, a
    // feature switched off).
    final disabled = onPressed == null && !loading;
    final colors = _colorsFor(variant, disabled: disabled);
    final textStyle = (labelStyle ?? Theme.of(context).textTheme.titleSmall)
        ?.copyWith(color: colors.foreground);

    final child = loading
        ? SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(colors.foreground),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 10)],
              // Flexible so a long label, a large text scale or a
              // translation shrinks to fit rather than overflowing the button.
              Flexible(
                child: Text(
                  label,
                  style: textStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 10), trailing!],
            ],
          );

    final radius = BorderRadius.circular(pill ? 999 : 14);
    final border = colors.border == null
        ? BorderSide.none
        : BorderSide(color: colors.border!, width: 1);

    final button = Material(
      color: colors.background,
      // A muted button shouldn't also cast a shadow suggesting it's raised.
      elevation: disabled ? 0 : elevation,
      shadowColor: AppColors.espressoDeep.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(borderRadius: radius, side: border),
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: radius,
        child: SizedBox(
          height: 56,
          // Dims the leading glyph (the Apple mark, the Google logo) along
          // with everything else — they carry their own colours, so muting the
          // palette alone would leave them at full strength.
          child: Center(
            child: disabled ? Opacity(opacity: 0.55, child: child) : child,
          ),
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  /// Muted stand-in for a disabled button: the fill washes out toward the page
  /// and the label drops to the secondary ink.
  _ButtonColors _muted(_ButtonColors c) => _ButtonColors(
    background: Color.lerp(c.background, AppColors.ivory, 0.78)!,
    foreground: AppColors.taupe,
    border: c.border == null ? null : AppColors.taupeSoft,
  );

  _ButtonColors _colorsFor(DrapeButtonVariant v, {bool disabled = false}) {
    final colors = _baseColorsFor(v);
    return disabled ? _muted(colors) : colors;
  }

  _ButtonColors _baseColorsFor(DrapeButtonVariant v) {
    switch (v) {
      case DrapeButtonVariant.filled:
        return const _ButtonColors(
          background: AppColors.espresso,
          foreground: AppColors.white,
        );
      case DrapeButtonVariant.outlined:
        return const _ButtonColors(
          background: AppColors.white,
          foreground: AppColors.ink,
          border: AppColors.taupeSoft,
        );
      case DrapeButtonVariant.text:
        return const _ButtonColors(
          background: Colors.transparent,
          foreground: AppColors.espresso,
        );
      case DrapeButtonVariant.apple:
        return const _ButtonColors(
          background: AppColors.black,
          foreground: AppColors.white,
        );
      case DrapeButtonVariant.google:
        return const _ButtonColors(
          background: AppColors.white,
          foreground: AppColors.ink,
          border: AppColors.taupeSoft,
        );
    }
  }
}

class _ButtonColors {
  final Color background;
  final Color foreground;
  final Color? border;
  const _ButtonColors({
    required this.background,
    required this.foreground,
    this.border,
  });
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFFEA4335),
            Color(0xFFFBBC05),
            Color(0xFF34A853),
          ],
          stops: [0.0, 0.33, 0.66, 1.0],
        ),
        shape: BoxShape.rectangle,
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
      child: const Center(
        child: Text(
          'G',
          style: TextStyle(
            color: AppColors.white,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
