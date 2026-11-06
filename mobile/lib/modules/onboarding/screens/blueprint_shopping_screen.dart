import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_choice_card.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_goals_screen.dart';

/// Step 7 of 8 — how the user feels about shopping and getting dressed (up
/// to three), their attitude to accessories, and the type of brands they
/// buy, with example brands for each.
class BlueprintShoppingScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/shopping';
  static const name = 'blueprint_shopping';

  const BlueprintShoppingScreen({super.key});

  @override
  ConsumerState<BlueprintShoppingScreen> createState() =>
      _BlueprintShoppingScreenState();
}

class _BlueprintShoppingScreenState
    extends ConsumerState<BlueprintShoppingScreen> {
  static const _maxFeelings = 3;

  static const _feelings = <({String value, String label, String detail})>[
    (
      value: 'confident',
      label: 'Confident and in control',
      detail: 'I know what works for me and enjoy the process.',
    ),
    (
      value: 'necessity',
      label: 'It’s just a necessity',
      detail: 'I want to look good but don’t want to spend time on it.',
    ),
    (
      value: 'frustrated',
      label: 'Often frustrated',
      detail: 'I struggle to find things that fit or look right.',
    ),
    (
      value: 'exploring',
      label: 'Ready for a change',
      detail: 'I want to elevate my style but don’t know where to start.',
    ),
  ];

  static const _accessories =
      <({String value, String label, List<IconData> icons, String badge})>[
        (
          value: 'none',
          label: 'None at all',
          icons: [Icons.do_not_disturb_on_outlined],
          badge: 'Pure clean',
        ),
        (
          value: 'minimal',
          label: 'Minimal, 1 to 3',
          icons: [Icons.watch_outlined, Icons.auto_awesome_outlined],
          badge: 'Classic',
        ),
        (
          value: 'statement',
          label: 'Statement pieces',
          icons: [Icons.diamond_outlined, Icons.local_activity_outlined],
          badge: 'Expressive',
        ),
      ];

  static const _brands =
      <
        ({
          String value,
          String label,
          String price,
          List<String> examples,
          String? note,
        })
      >[
        (
          value: 'fast_fashion',
          label: 'Accessible / Fast fashion',
          price: 'Usually under \$75 an item',
          examples: ['Zara', 'H&M', 'Uniqlo', 'Joe Fresh'],
          note: null,
        ),
        (
          value: 'premium',
          label: 'Premium brands',
          price: 'Usually \$75 to \$250 an item',
          examples: ['Aritzia', 'Theory', 'Vince'],
          note: null,
        ),
        (
          value: 'luxury',
          label: 'Designer / Luxury',
          price: 'Usually \$250 and up',
          examples: ['Max Mara', 'Saint Laurent', 'Loro Piana'],
          note: null,
        ),
        (
          value: 'mix',
          label: 'A high-low mix',
          price: 'A bit of everything',
          examples: [],
          note: 'e.g. Basics from one tier, statement pieces from another',
        ),
      ];

  final _picked = <String>{};
  String? _accessory;
  String? _brand;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider).blueprint;
    _picked.addAll(saved.shoppingFeelings.take(_maxFeelings));
    _accessory = saved.accessories;
    _brand = saved.brandTier;
  }

  bool get _complete =>
      _picked.isNotEmpty && _accessory != null && _brand != null;

  /// The accessories question, brought into view once three feelings are
  /// picked.
  final _accessoryQuestion = GlobalKey();

  /// The brands question, brought into view once accessories are answered.
  final _brandQuestion = GlobalKey();

  void _toggleFeeling(String value) {
    if (_leaving) return;
    var filled = false;
    setState(() {
      if (_picked.remove(value)) return;
      if (_picked.length < _maxFeelings) {
        _picked.add(value);
        filled = _picked.length == _maxFeelings;
      }
    });
    if (filled) revealNextQuestion(_accessoryQuestion);
  }

  void _onContinue() {
    if (!_complete || _leaving) return;
    ref
        .read(onboardingControllerProvider.notifier)
        .setBlueprintShopping(
          // In list order rather than pick order.
          feelings: [
            for (final f in _feelings)
              if (_picked.contains(f.value)) f.value,
          ],
          accessories: _accessory!,
          brandTier: _brand!,
        );
    // Ignore further taps until the user comes back to this step.
    setState(() => _leaving = true);
    context.pushNamed(BlueprintGoalsScreen.name).whenComplete(() {
      if (mounted) setState(() => _leaving = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return BlueprintScaffold(
      step: 7,
      canContinue: _complete,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'How do you feel about shopping and getting dressed?',
          subtitle: 'Pick up to 3 that sound like you.',
        ),
        const SizedBox(height: 24),
        for (final f in _feelings) ...[
          BlueprintChoiceCard(
            control: ChoiceControl.checkbox,
            label: f.label,
            detail: f.detail,
            selected: _picked.contains(f.value),
            onTap: () => _toggleFeeling(f.value),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 20),
        const _InsightCard(),
        const SizedBox(height: 32),
        BlueprintSubQuestion(
          key: _accessoryQuestion,
          'How do you feel about accessories?',
          note: 'From understated accents to intentional centerpieces.',
          italic: false,
        ),
        const SizedBox(height: 16),
        for (final a in _accessories) ...[
          BlueprintChoiceCard(
            label: a.label,
            trailing: _AccessoryBadge(
              icons: a.icons,
              text: a.badge,
              selected: _accessory == a.value,
            ),
            selected: _accessory == a.value,
            onTap: () {
              if (_leaving) return;
              final firstAnswer = _accessory == null;
              setState(() => _accessory = a.value);
              if (firstAnswer) revealNextQuestion(_brandQuestion);
            },
          ),
          if (a != _accessories.last) const SizedBox(height: 12),
        ],
        const SizedBox(height: 32),
        BlueprintSubQuestion(
          key: _brandQuestion,
          'Which types of brands do you prefer?',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cream,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.info_outline,
                  size: 18,
                  color: AppColors.espresso,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'The brands shown are just a few examples that represent '
                  'each category. We can’t list them all. Pick the option '
                  'closest to how you shop. Not seeing your favourites is '
                  'fine.',
                  style: body.copyWith(fontSize: 12, height: 1.6, color: _soft),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final b in _brands) ...[
          BlueprintChoiceCard(
            label: b.label,
            detail: b.price,
            footer: _BrandExamples(examples: b.examples, note: b.note),
            selected: _brand == b.value,
            onTap: () {
              if (!_leaving) setState(() => _brand = b.value);
            },
          ),
          const SizedBox(height: 12),
        ],
        Text(
          'Price ranges are a guide only.',
          style: body.copyWith(fontSize: 11, color: AppColors.taglineGrey),
        ),
      ],
    );
  }
}

// The mockup's own warm tones.
const _soft = BlueprintChoiceCard.soft;
const _line = BlueprintChoiceCard.line;
const _cream = BlueprintChoiceCard.radioFill;
const _sand = BlueprintChoiceCard.checkedFill;

/// An accessories answer's badge: its icons and a word for the look.
class _AccessoryBadge extends StatelessWidget {
  const _AccessoryBadge({
    required this.icons,
    required this.text,
    required this.selected,
  });

  final List<IconData> icons;
  final String text;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.tanFixed.withValues(alpha: 0.6)
            : AppColors.sand.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final icon in icons)
            Icon(
              icon,
              size: 15,
              color: selected ? AppColors.espresso : AppColors.taupe,
            ),
          const SizedBox(width: 6),
          Text(
            text,
            style: BlueprintText.optionSupport(context).copyWith(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.espresso : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}

/// A brand type's examples ("e.g." and name chips), or a note instead.
class _BrandExamples extends StatelessWidget {
  const _BrandExamples({required this.examples, required this.note});

  final List<String> examples;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    if (examples.isEmpty) {
      return Text(note ?? '', style: body.copyWith(fontSize: 12, color: _soft));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'e.g.',
          style: body.copyWith(fontSize: 11, color: AppColors.taglineGrey),
        ),
        for (final name in examples)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _sand,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              name,
              style: body.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
                color: AppColors.espresso,
              ),
            ),
          ),
      ],
    );
  }
}

/// "Atelier Insight": a photo, a quote, and a line about the brand's eye.
class _InsightCard extends StatelessWidget {
  const _InsightCard();

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ivoryHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1F512F1B),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                  spreadRadius: -3,
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/onboarding/atelier_insight.jpg',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATELIER INSIGHT',
                  style: body.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.espressoDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '“Simplicity is the keynote of all true elegance.”',
                  style: BlueprintText.heading(context).copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Refined tailoring matched to natural presence',
                  style: body.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
