import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_aesthetics_screen.dart';

/// Step 2 of 7 — body shape and how clothes should sit.
///
/// The two fit questions are three-stop sliders rather than free-range ones:
/// the backend stores a literal (`slim`/`regular`/`loose`), so a continuous
/// track would only invite a precision the data model doesn't have.
class BlueprintFitScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/fit';
  static const name = 'blueprint_fit';

  const BlueprintFitScreen({super.key});

  @override
  ConsumerState<BlueprintFitScreen> createState() => _BlueprintFitScreenState();
}

class _BlueprintFitScreenState extends ConsumerState<BlueprintFitScreen> {
  static const _shapes = <(String, String, IconData)>[
    ('rectangle', 'Rectangle', Icons.crop_square),
    ('triangle', 'Triangle', Icons.change_history),
    ('inverted_triangle', 'Inv. Triangle', Icons.details),
    ('trapezoid', 'Trapezoid', Icons.pentagon_outlined),
    ('oval', 'Oval', Icons.circle_outlined),
    ('hourglass', 'Hourglass', Icons.hourglass_empty),
  ];

  static const _tops = <(String, String)>[
    ('slim', 'Slim fitted'),
    ('regular', 'Regular fit'),
    ('loose', 'Loose'),
  ];

  static const _bottoms = <(String, String)>[
    ('skinny', 'Skinny fit'),
    ('relaxed', 'Relaxed fit'),
    ('baggy', 'Baggy'),
  ];

  final _fitQuestion = GlobalKey();

  String? _shape;
  // Default both sliders to the middle stop: it's the most common answer and
  // means the user only has to touch a slider they actually disagree with.
  int _topsIndex = 1;
  int _bottomsIndex = 1;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider).blueprint;
    _shape = saved.bodyShape;
    final t = _tops.indexWhere((e) => e.$1 == saved.fitTops);
    if (t != -1) _topsIndex = t;
    final b = _bottoms.indexWhere((e) => e.$1 == saved.fitBottoms);
    if (b != -1) _bottomsIndex = b;
  }

  Future<void> _onContinue() async {
    final shape = _shape;
    if (shape == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).setBlueprintFit(
            bodyShape: shape,
            fitTops: _tops[_topsIndex].$1,
            fitBottoms: _bottoms[_bottomsIndex].$1,
          );
      if (!mounted) return;
      context.pushNamed(BlueprintAestheticsScreen.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlueprintScaffold(
      step: 2,
      canContinue: _shape != null,
      loading: _submitting,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'Which body shape feels closest?',
          subtitle: 'Just a quick guess — full fit details come later.',
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.86,
          children: [
            for (final (value, label, icon) in _shapes)
              _ShapeCard(
                label: label,
                icon: icon,
                selected: _shape == value,
                onTap: () {
                  if (_submitting) return;
                  final firstAnswer = _shape == null;
                  setState(() => _shape = value);
                  if (firstAnswer) revealNextQuestion(_fitQuestion);
                },
              ),
          ],
        ),
        const SizedBox(height: 28),
        BlueprintQuestion(
          key: _fitQuestion,
          title: 'How do you prefer your clothes to fit?',
        ),
        const SizedBox(height: 20),
        _FitSlider(
          heading: 'Tops',
          stops: _tops,
          index: _topsIndex,
          onChanged: (i) => setState(() => _topsIndex = i),
        ),
        const SizedBox(height: 24),
        _FitSlider(
          heading: 'Bottoms',
          stops: _bottoms,
          index: _bottomsIndex,
          onChanged: (i) => setState(() => _bottomsIndex = i),
        ),
      ],
    );
  }
}

class _ShapeCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ShapeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ivoryWarm : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 30, color: AppColors.espresso),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BlueprintText.caption(context).copyWith(
                  color: selected ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A three-stop fit slider: the track snaps to the stop labels underneath it,
/// and the selected stop is the one rendered in full-strength ink.
class _FitSlider extends StatelessWidget {
  final String heading;
  final List<(String, String)> stops;
  final int index;
  final ValueChanged<int> onChanged;

  const _FitSlider({
    required this.heading,
    required this.stops,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(heading, style: BlueprintText.option(context)),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: AppColors.espresso,
            inactiveTrackColor: AppColors.sand,
            thumbColor: AppColors.espresso,
            overlayColor: AppColors.espresso.withValues(alpha: 0.1),
            activeTickMarkColor: AppColors.espresso,
            inactiveTickMarkColor: AppColors.taupeSoft,
          ),
          child: Slider(
            value: index.toDouble(),
            min: 0,
            max: (stops.length - 1).toDouble(),
            divisions: stops.length - 1,
            label: stops[index].$2,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < stops.length; i++)
              Expanded(
                child: Text(
                  stops[i].$2,
                  textAlign: i == 0
                      ? TextAlign.start
                      : i == stops.length - 1
                          ? TextAlign.end
                          : TextAlign.center,
                  style: BlueprintText.caption(context).copyWith(
                    color: i == index ? AppColors.ink : AppColors.inkSoft,
                    fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
