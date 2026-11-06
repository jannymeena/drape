import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../screens/blueprint_aesthetics_screen.dart';
import '../screens/blueprint_fit_screen.dart';
import '../widgets/blueprint_scaffold.dart';
import 'shape_finder_controller.dart';
import '../widgets/pipeda_note.dart';
import '../widgets/step_swipe.dart';

// ─── Leaving the sub-flow ───────────────────────────────────────────────────

/// Back to step 2's shape grid, closing every sub-flow screen above it.
void backToShapeGrid(BuildContext context) {
  Navigator.of(context).popUntil(
    (route) => route.settings.name == BlueprintFitScreen.name || route.isFirst,
  );
}

/// Saves step 2 with [shape] (null = "Not sure") and the fit answers carried
/// from it, then carries on with the main flow at step 3. The save runs in the
/// background like every step's (see OnboardingController).
void finishShapeFinder(BuildContext context, WidgetRef ref, String? shape) {
  final finder = ref.read(shapeFinderProvider);
  ref
      .read(onboardingControllerProvider.notifier)
      .setBlueprintFit(
        bodyShape: shape,
        fitTops: finder.fitTops,
        fitBottoms: finder.fitBottoms,
      );
  context.goNamed(BlueprintAestheticsScreen.name);
}

// ─── Chrome ─────────────────────────────────────────────────────────────────

/// The sub-flow's page: the Blueprint header (back button, centred [section]
/// label, "Step 2 of 8" pill) with an optional italic [title] under it, the
/// step 2 progress line, a
/// scrolling body, and an optional pinned [bottom].
class ShapeFinderScaffold extends StatelessWidget {
  const ShapeFinderScaffold({
    super.key,
    required this.section,
    required this.children,
    this.title,
    this.bottom,
    this.onBack,
  });

  final String section;
  final String? title;
  final List<Widget> children;
  final Widget? bottom;

  /// Defaults to popping this screen.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final caption = BlueprintText.caption(context);
    // Dark status-bar icons, set explicitly: coming back from the dark avatar
    // reveal would otherwise leave them light on this light page.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.ivory,
        // Swipe right to go back, like the back button.
        body: StepSwipe(
          onBack: onBack ?? () => Navigator.of(context).maybePop(),
          child: SafeArea(
            child: Column(
              children: [
                // A Hero, so the overline and progress line hold still while
                // the page slides between the sub-flow's screens.
                Hero(
                  tag: 'shape-finder-header',
                  flightShuttleBuilder: _pinnedHeaderFlight,
                  // Laid out like the Blueprint steps' header: back on the
                  // left, the step pill on the right, the section centred.
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: IconButton(
                                  onPressed:
                                      onBack ??
                                      () => Navigator.of(context).maybePop(),
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    size: 28,
                                  ),
                                  color: AppColors.ink,
                                  tooltip: 'Go back',
                                ),
                              ),
                            ),
                            Text(
                              section.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: caption.copyWith(
                                fontSize: 11,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: BlueprintStepPill(step: 2),
                              ),
                            ),
                          ],
                        ),
                        if (title != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              title!,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall!
                                  .copyWith(
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 20,
                                    color: AppColors.espressoDark,
                                  ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(left: 12),
                          child: BlueprintProgressLine(
                            value: 2 / kBlueprintSteps,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ),
                if (bottom != null)
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    decoration: const BoxDecoration(
                      color: AppColors.ivory,
                      border: Border(top: BorderSide(color: AppColors.sand)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        bottom!,
                        const SizedBox(height: 8),
                        const PipedaNote(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The header's stand-in while a sub-flow screen slides: the destination's
/// header on the page colour, top-aligned and clipped, since headers with and
/// without a title differ in height.
Widget _pinnedHeaderFlight(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHeroContext,
  BuildContext toHeroContext,
) {
  return Material(
    color: AppColors.ivory,
    child: ClipRect(
      child: OverflowBox(
        alignment: Alignment.topCenter,
        maxHeight: double.infinity,
        child: (toHeroContext.widget as Hero).child,
      ),
    ),
  );
}

/// A big serif heading with an optional line under it.
class ShapeFinderHeading extends StatelessWidget {
  const ShapeFinderHeading(
    this.title, {
    super.key,
    this.body,
    this.center = false,
  });

  final String title;
  final String? body;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final align = center ? TextAlign.center : TextAlign.start;
    return Column(
      crossAxisAlignment: center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          title,
          textAlign: align,
          style: BlueprintText.heading(
            context,
          ).copyWith(color: AppColors.espressoDark),
        ),
        if (body != null) ...[
          const SizedBox(height: 8),
          Text(
            body!,
            textAlign: align,
            style: BlueprintText.subtitle(
              context,
            ).copyWith(fontSize: 14, height: 1.45),
          ),
        ],
      ],
    );
  }
}

/// The espresso call to action.
class ShapeFinderPrimaryButton extends StatelessWidget {
  const ShapeFinderPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? leading;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.espressoDark, AppColors.espresso],
                )
              : null,
          color: enabled ? null : AppColors.taupeSoft,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: _ButtonLabel(
              label: label,
              leading: leading,
              trailing: trailing,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// The quieter alternative to [ShapeFinderPrimaryButton].
class ShapeFinderSecondaryButton extends StatelessWidget {
  const ShapeFinderSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Material(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: _ButtonLabel(
            label: label,
            leading: leading,
            color: onPressed == null ? AppColors.taupe : AppColors.espressoDark,
          ),
        ),
      ),
    );
  }
}

class _ButtonLabel extends StatelessWidget {
  const _ButtonLabel({
    required this.label,
    required this.color,
    this.leading,
    this.trailing,
  });

  final String label;
  final Color color;
  final IconData? leading;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading != null) ...[
          Icon(leading, size: 20, color: color),
          const SizedBox(width: 10),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Icon(trailing, size: 20, color: color),
        ],
      ],
    );
  }
}

/// A text link with an optional icon either side.
class ShapeFinderLink extends StatelessWidget {
  const ShapeFinderLink({
    super.key,
    required this.label,
    required this.onPressed,
    this.leading,
    this.trailing,
    this.underline = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? leading;
  final IconData? trailing;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: AppColors.espressoDark),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              Icon(leading, size: 18),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: BlueprintText.option(context).copyWith(
                  fontSize: 14,
                  color: AppColors.espressoDark,
                  decoration: underline ? TextDecoration.underline : null,
                  decorationColor: AppColors.espressoDark,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              Icon(trailing, size: 18),
            ],
          ],
        ),
      ),
    );
  }
}

/// A white card on the soft shadow the sub-flow uses throughout.
class ShapeFinderCard extends StatelessWidget {
  const ShapeFinderCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.white,
    this.shadow = true,
    this.radius = 20,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final bool shadow;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? const [
                BoxShadow(
                  color: Color(0x0F2A1810),
                  blurRadius: 24,
                  spreadRadius: -4,
                  offset: Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: child,
    );
  }
}

/// An icon in a tinted circle.
class ShapeFinderBadgeIcon extends StatelessWidget {
  const ShapeFinderBadgeIcon(
    this.icon, {
    super.key,
    this.size = 36,
    this.background = AppColors.sageDim,
    this.color = AppColors.sage,
  });

  final IconData icon;
  final double size;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}
