import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_goals_screen.dart';

/// Step 7 of 8 — how the user feels about shopping and getting dressed (up
/// to three), their attitude to accessories, and the type of brands they
/// buy, with example brands for each.
///
/// "Add a favourite brand" isn't designed yet: shown as in the mockup, it
/// does nothing.
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
    // The earlier habits step stored one feeling; it carries over.
    final feelings = saved.shoppingFeelings.isNotEmpty
        ? saved.shoppingFeelings
        : [?saved.shoppingFeeling];
    _picked.addAll(feelings.take(_maxFeelings));
    _accessory = saved.accessories;
    _brand = saved.brandTier;
  }

  bool get _complete =>
      _picked.isNotEmpty && _accessory != null && _brand != null;

  void _toggleFeeling(String value) {
    if (_leaving) return;
    setState(() {
      if (_picked.remove(value)) return;
      if (_picked.length < _maxFeelings) _picked.add(value);
    });
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
          _CheckRow(
            label: f.label,
            detail: f.detail,
            checked: _picked.contains(f.value),
            onTap: () => _toggleFeeling(f.value),
          ),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'You can pick up to 3. Untick one to change.',
                  style: body.copyWith(
                    fontSize: 11,
                    color: AppColors.taglineGrey,
                  ),
                ),
              ),
              Text(
                '${_picked.length} of $_maxFeelings selected',
                style: body.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.taglineGrey,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const _InsightCard(),
        const SizedBox(height: 32),
        const BlueprintSubQuestion(
          'How do you feel about accessories?',
          note: 'From understated accents to intentional centerpieces.',
          italic: false,
        ),
        const SizedBox(height: 16),
        for (final a in _accessories) ...[
          _AccessoryRow(
            label: a.label,
            icons: a.icons,
            badge: a.badge,
            selected: _accessory == a.value,
            onTap: () {
              if (!_leaving) setState(() => _accessory = a.value);
            },
          ),
          if (a != _accessories.last) const SizedBox(height: 12),
        ],
        const SizedBox(height: 32),
        const BlueprintSubQuestion('Which types of brands do you prefer?'),
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
          _BrandCard(
            label: b.label,
            price: b.price,
            examples: b.examples,
            note: b.note,
            selected: _brand == b.value,
            onTap: () {
              if (!_leaving) setState(() => _brand = b.value);
            },
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: Material(
            color: Colors.transparent,
            shape: const StadiumBorder(
              side: BorderSide(color: AppColors.taupeSoft),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              // Not designed yet: shown as in the mockup, does nothing.
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 16, color: AppColors.espresso),
                    const SizedBox(width: 6),
                    Text(
                      'Add a favourite brand',
                      style: body.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.espresso,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Price ranges are a guide only.',
          style: body.copyWith(fontSize: 11, color: AppColors.taglineGrey),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 15, color: AppColors.taupe),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Stored securely in Canada. 🇨🇦',
                style: body.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.taupe,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// The mockup's own warm tones.
const _ink = Color(0xFF2A1810);
const _soft = Color(0xFF6B5848);
const _line = Color(0xFFE8D8C8);
const _cream = Color(0xFFFDF5EE);
const _sandSelected = Color(0xFFF5E8D8);

/// A bordered option card: espresso border and a warm fill when selected.
class _OptionShell extends StatelessWidget {
  const _OptionShell({
    required this.selected,
    required this.selectedColor,
    required this.onTap,
    required this.child,
    this.padding = const EdgeInsets.all(15),
  });

  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.espresso : _line,
          width: selected ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.label,
    required this.detail,
    required this.checked,
    required this.onTap,
  });

  final String label;
  final String detail;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return Semantics(
      checked: checked,
      child: _OptionShell(
        selected: checked,
        selectedColor: _sandSelected,
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: checked ? AppColors.espresso : AppColors.white,
                borderRadius: BorderRadius.circular(6),
                border: checked ? null : Border.all(color: AppColors.taupeSoft),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 16, color: AppColors.white)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: checked ? _ink : AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: body.copyWith(
                      fontSize: 12,
                      height: 1.6,
                      color: _soft,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round radio: empty ring, or espresso with a white dot.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: selected ? AppColors.espresso : Colors.transparent,
        shape: BoxShape.circle,
        border: selected ? null : Border.all(color: AppColors.taupeSoft),
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

class _AccessoryRow extends StatelessWidget {
  const _AccessoryRow({
    required this.label,
    required this.icons,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<IconData> icons;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    final tint = selected ? AppColors.espresso : AppColors.inkSoft;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: _OptionShell(
        selected: selected,
        selectedColor: _cream,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 32),
          child: Row(
            children: [
              _Radio(selected: selected),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: body.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? AppColors.espresso : AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
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
                      badge,
                      style: body.copyWith(
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: tint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandCard extends StatelessWidget {
  const _BrandCard({
    required this.label,
    required this.price,
    required this.examples,
    required this.note,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String price;
  final List<String> examples;
  final String? note;
  final bool selected;
  final VoidCallback onTap;

  /// Lines the examples up under the label: the radio and its gap.
  static const _indent = 34.0;

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      child: _OptionShell(
        selected: selected,
        selectedColor: _cream,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: _Radio(selected: selected),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: body.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? AppColors.espresso : AppColors.ink,
                        ),
                      ),
                      Text(
                        price,
                        style: body.copyWith(
                          fontSize: 11,
                          color: selected ? _soft : AppColors.taglineGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(left: _indent),
              child: examples.isEmpty
                  ? Text(
                      note ?? '',
                      style: body.copyWith(fontSize: 12, color: _soft),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'e.g.',
                          style: body.copyWith(
                            fontSize: 11,
                            color: AppColors.taglineGrey,
                          ),
                        ),
                        for (final name in examples)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _sandSelected,
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
                    ),
            ),
          ],
        ),
      ),
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
