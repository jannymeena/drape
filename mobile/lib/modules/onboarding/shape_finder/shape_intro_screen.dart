import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/blueprint_scaffold.dart';
import 'shape_finder_ui.dart';
import 'shape_measure_screen.dart';
import 'shape_photo_tips_screen.dart';

/// "Not sure?" lands here: why we ask, and the choice — four measurements
/// (the main path) or a full-body photo. "Skip for now" saves step 2 as
/// "Not sure" and carries on.
class ShapeIntroScreen extends ConsumerWidget {
  static const path = '/onboarding/blueprint/shape';
  static const name = 'shape_intro';

  const ShapeIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final caption = BlueprintText.caption(context);
    return ShapeFinderScaffold(
      section: 'Your shape',
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShapeFinderPrimaryButton(
            label: 'Enter measurements',
            trailing: Icons.arrow_forward,
            onPressed: () => context.pushNamed(ShapeMeasureScreen.name),
          ),
          const SizedBox(height: 10),
          ShapeFinderSecondaryButton(
            label: 'Use a photo instead',
            leading: Icons.photo_camera_outlined,
            onPressed: () => context.pushNamed(ShapePhotoTipsScreen.name),
          ),
        ],
      ),
      children: [
        Row(
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ivoryWarm,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.sage,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'MEASUREMENTS • 4 POINTS',
                        overflow: TextOverflow.ellipsis,
                        style: caption.copyWith(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                          color: AppColors.espressoDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('About 2 min', style: caption.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 14),
        const ShapeFinderHeading(
          'Build your Atelier silhouette',
          body:
              'Four measurements with a soft tape, or one full-body photo. '
              'Every drape, silhouette and size suggestion is then calibrated '
              'to your proportions.',
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(child: _Stat(Icons.schedule, '2 mins', 'Quick & guided')),
            SizedBox(width: 10),
            Expanded(
              child: _Stat(Icons.straighten, '4 points', 'Step-by-step'),
            ),
            SizedBox(width: 10),
            Expanded(
              child: _Stat(
                Icons.photo_camera_outlined,
                'Or 1 photo',
                'AI estimate',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _AtelierCard(),
        const SizedBox(height: 20),
        ShapeFinderCard(
          color: AppColors.ivoryDim,
          shadow: false,
          child: const Column(
            children: [
              _Benefit(
                Icons.check_circle_outline,
                'Flawless drape on your real proportions',
                'No generic size charts — cuts chosen for your shoulder, '
                    'waist and hip balance.',
              ),
              SizedBox(height: 16),
              _Benefit(
                Icons.auto_awesome_outlined,
                'Size suggestions that fit',
                'Fit notes on the pieces we recommend, based on your shape.',
              ),
              SizedBox(height: 16),
              _Benefit(
                Icons.history,
                'Update anytime in under 30 seconds',
                'Retune a single measurement whenever you like.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.ivoryWarm,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.lock_outline,
                size: 18,
                color: AppColors.inkSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Biometric data stays privately encrypted in Canada. Never '
                  'marketed or shared. • PIPEDA compliant 🇨🇦',
                  style: BlueprintText.optionSupport(
                    context,
                  ).copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ShapeFinderLink(
          label: 'Skip for now — I’ll do this later in my profile',
          underline: true,
          onPressed: () => finishShapeFinder(context, ref, null),
        ),
        Text(
          'You’ll still explore curated capsule edits today; silhouette '
          'tailoring unlocks once it’s done.',
          textAlign: TextAlign.center,
          style: caption.copyWith(fontSize: 12),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.caption);

  final IconData icon;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.ivoryDim,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShapeFinderBadgeIcon(
            icon,
            size: 34,
            background: AppColors.ivoryHigh,
            color: AppColors.espressoDark,
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: BlueprintText.option(
              context,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          Text(
            caption,
            style: BlueprintText.caption(context).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// The editorial card: the atelier figure on a warm backdrop, with a couple of
/// measurement call-outs floating beside it.
class _AtelierCard extends StatelessWidget {
  const _AtelierCard();

  @override
  Widget build(BuildContext context) {
    final caption = BlueprintText.caption(context);
    return ShapeFinderCard(
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.sage,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'SILHOUETTE CALIBRATION',
                style: caption.copyWith(
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sage,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 210,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFE9DFD3), Color(0xFFC9B39C)],
                ),
              ),
              child: Stack(
                children: [
                  Center(
                    child: SvgPicture.asset(
                      'assets/onboarding/atelier_avatar.svg',
                      height: 190,
                    ),
                  ),
                  const Positioned(
                    left: 14,
                    top: 40,
                    child: _CallOut(Icons.tune, 'Chest • 92 cm'),
                  ),
                  const Positioned(
                    right: 14,
                    bottom: 40,
                    child: _CallOut(Icons.check, 'Waist • 74 cm'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.view_in_ar, size: 18, color: AppColors.espresso),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'The Atelier avatar: ',
                        style: caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.espressoDark,
                        ),
                      ),
                      const TextSpan(
                        text:
                            'your personal silhouette takes shape with every '
                            'measurement you save.',
                      ),
                    ],
                  ),
                  style: caption.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CallOut extends StatelessWidget {
  const _CallOut(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.espressoDark),
          const SizedBox(width: 5),
          Text(
            label,
            style: BlueprintText.caption(
              context,
            ).copyWith(fontSize: 11, color: AppColors.espressoDark),
          ),
        ],
      ),
    );
  }
}

class _Benefit extends StatelessWidget {
  const _Benefit(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ShapeFinderBadgeIcon(icon, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: BlueprintText.option(
                  context,
                ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: BlueprintText.optionSupport(
                  context,
                ).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
