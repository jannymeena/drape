import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_chip.dart';
import '../widgets/blueprint_choice_card.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_shopping_screen.dart';

typedef _Option = ({String value, String label});

/// Step 6 of 8 — work and lifestyle: what the user does (up to two,
/// "Other" in their own words), the dress code, how dressed up a typical day
/// is, and where they want to make a better impression.
///
/// "Not currently working" stands alone: picking it clears the other
/// occupations and turns the dress-code question off.
class BlueprintWorkScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/work';
  static const name = 'blueprint_work';

  const BlueprintWorkScreen({super.key});

  @override
  ConsumerState<BlueprintWorkScreen> createState() =>
      _BlueprintWorkScreenState();
}

class _BlueprintWorkScreenState extends ConsumerState<BlueprintWorkScreen> {
  static const _occupations = <_Option>[
    (value: 'office_corporate', label: 'Office / Corporate'),
    (value: 'business', label: 'Business'),
    (value: 'marketing', label: 'Marketing'),
    (value: 'media_communications', label: 'Media / Communications'),
    (value: 'tech_remote', label: 'Tech / Remote'),
    (value: 'creative_design', label: 'Creative / Design'),
    (value: 'healthcare', label: 'Healthcare'),
    (value: 'education', label: 'Education'),
    (value: 'trades_outdoor', label: 'Trades / Outdoor'),
    (value: 'hospitality_retail', label: 'Hospitality / Retail'),
    (value: 'student', label: 'Student'),
    (value: 'self_employed', label: 'Self-Employed'),
    (value: _notWorking, label: 'Not currently working'),
    (value: _other, label: 'Other'),
  ];
  static const _notWorking = 'not_working';
  static const _other = 'other';
  static const _maxOccupations = 2;
  static const _otherMax = 40;

  static const _dressCodes = <_Option>[
    (value: 'casual', label: 'Casual'),
    (value: 'smart_casual', label: 'Smart Casual'),
    (value: 'business_casual', label: 'Business Casual'),
    (value: 'business_formal', label: 'Business Formal'),
    (value: 'uniform_other', label: 'Uniform'),
  ];

  static const _formality = <_Option>[
    (value: 'athleisure', label: 'Athleisure'),
    (value: 'casual', label: 'Casual'),
    (value: 'smart_casual', label: 'Smart casual'),
    (value: 'business', label: 'Business'),
    (value: 'formal', label: 'Formal'),
  ];

  static const _impressions = <_Option>[
    (value: 'work', label: 'Work / Professional settings'),
    (value: 'dating', label: 'Dating / Social situations'),
    (value: 'both', label: 'Both equally'),
  ];

  /// Picked occupations, in the order picked.
  final _picked = <String>[];
  late final TextEditingController _otherText;
  String? _dressCode;
  int _formalityIndex = 2; // Smart casual
  String? _impression;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider).blueprint;
    _picked.addAll(saved.occupations.take(_maxOccupations));
    _otherText = TextEditingController(text: saved.occupationOther ?? '');
    _dressCode = saved.dressCode;
    final f = _formality.indexWhere((o) => o.value == saved.dayFormality);
    if (f >= 0) _formalityIndex = f;
    // Only the three offered here; the earlier step also had "content".
    _impression = _impressions.any((o) => o.value == saved.impressionGoal)
        ? saved.impressionGoal
        : null;
    _otherText.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _otherText.dispose();
    super.dispose();
  }

  bool get _notWorkingPicked => _picked.contains(_notWorking);
  bool get _otherPicked => _picked.contains(_other);

  bool get _complete =>
      _picked.isNotEmpty &&
      (!_otherPicked || _otherText.text.trim().isNotEmpty) &&
      (_notWorkingPicked || _dressCode != null) &&
      _impression != null;

  /// Brought into view once the question before is done: the dress code
  /// after a second occupation; the typical day after the dress code, or
  /// straight after "Not currently working" (which has no dress code).
  final _dressCodeQuestion = GlobalKey();
  final _dayQuestion = GlobalKey();

  void _toggleOccupation(String value) {
    if (_leaving) return;
    GlobalKey? next;
    setState(() {
      if (_picked.remove(value)) return;
      if (value == _notWorking) {
        // Stands alone, and there's no dress code to ask about.
        _picked
          ..clear()
          ..add(value);
        _dressCode = null;
        next = _dayQuestion;
        return;
      }
      _picked.remove(_notWorking);
      if (_picked.length >= _maxOccupations) return; // up to two
      _picked.add(value);
      // Not while "Other" waits to be described: its box is up here.
      if (_picked.length == _maxOccupations && !_otherPicked) {
        next = _dressCodeQuestion;
      }
    });
    if (next case final next?) revealNextQuestion(next);
  }

  void _onContinue() {
    if (!_complete || _leaving) return;
    final occupations = [
      for (final o in _occupations)
        if (_picked.contains(o.value)) o.value,
    ];
    // Saved in the background; see OnboardingController._save.
    ref
        .read(onboardingControllerProvider.notifier)
        .setBlueprintWork(
          occupations: occupations,
          occupationOther: _otherPicked ? _otherText.text.trim() : null,
          dressCode: _notWorkingPicked ? null : _dressCode,
          dayFormality: _formality[_formalityIndex].value,
          impressionGoal: _impression!,
        );
    // Ignore further taps until the user comes back to this step.
    setState(() => _leaving = true);
    context.pushNamed(BlueprintShoppingScreen.name).whenComplete(() {
      if (mounted) setState(() => _leaving = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlueprintScaffold(
      step: 6,
      canContinue: _complete,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'What do you do for work?',
          subtitle: 'Helps us match outfits to your day-to-day.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in _occupations)
              BlueprintChip(
                label: o.label,
                selected: _picked.contains(o.value),
                onTap: () => _toggleOccupation(o.value),
              ),
          ],
        ),
        if (_otherPicked) ...[
          const SizedBox(height: 16),
          _OtherField(controller: _otherText, max: _otherMax),
        ],
        const SizedBox(height: 24),
        BlueprintSubQuestion(
          key: _dressCodeQuestion,
          'What’s the dress code like?',
          note: 'Skipped automatically if you’re not currently working',
          italic: false,
        ),
        const SizedBox(height: 12),
        // Not working: nothing to ask, so the chips are switched off.
        Opacity(
          opacity: _notWorkingPicked ? 0.4 : 1,
          child: IgnorePointer(
            ignoring: _notWorkingPicked,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in _dressCodes)
                  BlueprintChip(
                    label: d.label,
                    selected: !_notWorkingPicked && _dressCode == d.value,
                    onTap: () {
                      if (_leaving) return;
                      final firstAnswer = _dressCode == null;
                      setState(() => _dressCode = d.value);
                      if (firstAnswer) revealNextQuestion(_dayQuestion);
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
        BlueprintSubQuestion(
          key: _dayQuestion,
          'How dressed up is a typical day?',
        ),
        const SizedBox(height: 16),
        _FormalitySlider(
          labels: [for (final f in _formality) f.label],
          index: _formalityIndex,
          onChanged: (i) {
            if (!_leaving) setState(() => _formalityIndex = i);
          },
        ),
        const SizedBox(height: 28),
        const BlueprintSubQuestion(
          'Where do you want to make a better impression?',
        ),
        const SizedBox(height: 12),
        for (final i in _impressions) ...[
          BlueprintChoiceCard(
            label: i.label,
            selected: _impression == i.value,
            onTap: () {
              if (!_leaving) setState(() => _impression = i.value);
            },
          ),
          if (i != _impressions.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// The soft shadow on the mockup's white controls (`shadow-sm`).
const _softShadow = [
  BoxShadow(color: Color(0x0D000000), blurRadius: 2, offset: Offset(0, 1)),
];

/// "Tell us what you do", for "Other": up to [max] characters, counted.
class _OtherField extends StatelessWidget {
  const _OtherField({required this.controller, required this.max});

  final TextEditingController controller;
  final int max;

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: _softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tell us what you do',
                  style: body.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              Text(
                '${controller.text.length} / $max',
                style: body.copyWith(fontSize: 11, color: AppColors.taupe),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            maxLength: max,
            textCapitalization: TextCapitalization.words,
            style: body.copyWith(fontSize: 14, color: AppColors.ink),
            decoration: InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              counterText: '',
              hintText: 'e.g. Architectural Restoration, Brand Strategist',
              hintStyle: body.copyWith(
                fontSize: 14,
                color: AppColors.taupe.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Five stops, tapped or dragged to; the current one is highlighted in the
/// labels underneath.
class _FormalitySlider extends StatelessWidget {
  const _FormalitySlider({
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  static const _inset = 8.0; // px-2: the track's ends sit in from the sides

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return LayoutBuilder(
      builder: (context, box) {
        final track = box.maxWidth - 2 * _inset;
        final stops = labels.length - 1;
        double xOf(int i) => _inset + track * i / stops;
        void pick(double x) {
          final i = ((x - _inset) / track * stops).round().clamp(0, stops);
          if (i != index) onChanged(i);
        }

        final thumbX = xOf(index);
        return Semantics(
          slider: true,
          value: labels[index],
          increasedValue: index < stops ? labels[index + 1] : null,
          decreasedValue: index > 0 ? labels[index - 1] : null,
          onIncrease: index < stops ? () => onChanged(index + 1) : null,
          onDecrease: index > 0 ? () => onChanged(index - 1) : null,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => pick(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.centerLeft,
                    children: [
                      // Track, and its filled part up to the thumb.
                      Positioned(
                        left: _inset,
                        right: _inset,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.ivoryHigh,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Positioned(
                        left: _inset,
                        width: thumbX - _inset,
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: AppColors.espresso,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      for (var i = 0; i <= stops; i++)
                        Positioned(
                          left: xOf(i) - (i == index ? 5 : 4),
                          child: Container(
                            width: i == index ? 10 : 8,
                            height: i == index ? 10 : 8,
                            decoration: BoxDecoration(
                              color: i <= index
                                  ? AppColors.espresso
                                  : AppColors.sand,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      // Thumb.
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 150),
                        left: thumbX - 12,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: const BoxDecoration(
                            color: AppColors.espresso,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x59512F1B),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.ivory,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Each label under its stop: the end ones flush with the
                // track's ends, the rest centred on theirs.
                SizedBox(
                  height: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (var i = 0; i <= stops; i++)
                        Positioned(
                          left: i == stops ? null : (i == 0 ? 0 : xOf(i)),
                          right: i == stops ? 0 : null,
                          child: FractionalTranslation(
                            translation: Offset(
                              i == 0 || i == stops ? 0 : -0.5,
                              0,
                            ),
                            child: Text(
                              labels[i],
                              style: body.copyWith(
                                fontSize: 11,
                                fontWeight: i == index
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: i == index
                                    ? AppColors.espressoDark
                                    : AppColors.taupe,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
