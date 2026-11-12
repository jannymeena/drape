import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/body_shapes.dart';
import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import '../widgets/line_glyph.dart';
import '../widgets/measurement_guide.dart';
import 'shape_finder_controller.dart';
import 'shape_finder_ui.dart';
import 'shape_result_screen.dart';

/// The measurements path: chest (bust), waist and hips, plus optional
/// shoulders, in cm or inches. Values are kept in centimetres.
class ShapeMeasureScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/shape/measure';
  static const name = 'shape_measure';

  const ShapeMeasureScreen({super.key});

  @override
  ConsumerState<ShapeMeasureScreen> createState() => _ShapeMeasureScreenState();
}

class _Spec {
  const _Spec(
    this.field,
    this.description,
    this.glyph, {
    required this.minCm,
    required this.maxCm,
    this.required = true,
  });

  final MeasurementField field;
  final String description;
  final LineGlyphData glyph;
  final double minCm;
  final double maxCm;
  final bool required;

  String title(BodyShapeSet set) => switch (field) {
    MeasurementField.chest => set == BodyShapeSet.womens ? 'Bust' : 'Chest',
    MeasurementField.waist => 'Waist',
    MeasurementField.hips => 'Hips',
    _ => 'Shoulders',
  };
}

// Line art from the mockup, 48×48: guide strokes faint, the tape dashed, and
// a dot where it sits.
const _g = GlyphTone.guide;
const _tape = [2.0, 3.0];

const _specs = [
  _Spec(
    MeasurementField.chest,
    'Around the fullest part of your chest.',
    LineGlyphData(48, 48, [
      GlyphStroke.path('M16 10 C 19 14, 29 14, 32 10', tone: _g, width: 1.6),
      GlyphStroke.path(
        'M14 10 L 10 20 C 12 28, 16 32, 24 32 C 32 32, 36 28, 38 20 L 34 10',
        width: 1.6,
      ),
      GlyphStroke.path('M8 22 C 14 26, 34 26, 40 22', width: 1.8, dash: _tape),
      GlyphStroke.ellipse(
        24,
        24,
        2.5,
        2.5,
        tone: GlyphTone.body,
        width: 0,
        fill: 1,
      ),
    ]),
    minCm: 60,
    maxCm: 180,
  ),
  _Spec(
    MeasurementField.waist,
    'Narrowest point of your torso, above the navel.',
    LineGlyphData(48, 48, [
      GlyphStroke.path(
        'M12 10 L 16 24 C 18 25, 20 25, 24 25 C 28 25, 30 25, 32 24 L 36 10',
        tone: _g,
        width: 1.6,
      ),
      GlyphStroke.path(
        'M16 24 L 12 38 C 18 40, 30 40, 36 38 L 32 24',
        width: 1.6,
      ),
      GlyphStroke.path('M13 24 C 19 28, 29 28, 35 24', width: 1.8, dash: _tape),
      GlyphStroke.ellipse(
        24,
        26,
        2.5,
        2.5,
        tone: GlyphTone.body,
        width: 0,
        fill: 1,
      ),
    ]),
    minCm: 45,
    maxCm: 180,
  ),
  _Spec(
    MeasurementField.hips,
    'Widest circumference of your hips and seat.',
    LineGlyphData(48, 48, [
      GlyphStroke.path(
        'M16 12 C 16 16, 12 24, 10 32 C 16 38, 32 38, 38 32 C 36 24, 32 16, 32 12',
        tone: _g,
        width: 1.6,
      ),
      GlyphStroke.path('M8 29 C 14 34, 34 34, 40 29', width: 2, dash: _tape),
      GlyphStroke.ellipse(
        24,
        31.5,
        2.5,
        2.5,
        tone: GlyphTone.body,
        width: 0,
        fill: 1,
      ),
    ]),
    minCm: 60,
    maxCm: 190,
  ),
  _Spec(
    MeasurementField.shoulders,
    'Straight across the upper back, point to point.',
    LineGlyphData(48, 48, [
      GlyphStroke.path('M12 28 C 16 18, 32 18, 36 28', tone: _g, width: 1.6),
      GlyphStroke.path('M8 20 C 14 16, 34 16, 40 20', width: 1.8),
      GlyphStroke.path('M10 20 L 38 20', width: 1.8, dash: _tape),
      GlyphStroke.ellipse(
        24,
        18,
        2.5,
        2.5,
        tone: GlyphTone.body,
        width: 0,
        fill: 1,
      ),
    ]),
    minCm: 25,
    maxCm: 80,
    required: false,
  ),
];

const _cmPerInch = 2.54;

/// [cm] in the display unit, without a trailing ".0".
String _display(double cm, {required bool imperial}) {
  final v = imperial ? cm / _cmPerInch : cm;
  final rounded = (v * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
}

class _ShapeMeasureScreenState extends ConsumerState<ShapeMeasureScreen> {
  late final Map<MeasurementField, TextEditingController> _text;
  bool _saveToProfile = true;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final finder = ref.read(shapeFinderProvider);
    _text = {
      for (final s in _specs)
        s.field: TextEditingController(
          text: switch (finder.cm[s.field]) {
            final cm? => _display(cm, imperial: finder.imperial),
            null => '',
          },
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _text.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// The entered value in cm, or null when empty or out of range.
  double? _cm(_Spec spec, String text, {required bool imperial}) {
    final v = double.tryParse(text.trim());
    if (v == null) return null;
    final cm = imperial ? v * _cmPerInch : v;
    return cm >= spec.minCm && cm <= spec.maxCm ? cm : null;
  }

  void _onChanged(_Spec spec, String text) {
    final imperial = ref.read(shapeFinderProvider).imperial;
    ref
        .read(shapeFinderProvider.notifier)
        .setMeasurement(spec.field, _cm(spec, text, imperial: imperial));
  }

  void _setUnit(bool imperial) {
    final finder = ref.read(shapeFinderProvider);
    if (finder.imperial == imperial) return;
    for (final s in _specs) {
      final cm = finder.cm[s.field];
      if (cm != null) _text[s.field]!.text = _display(cm, imperial: imperial);
    }
    ref.read(shapeFinderProvider.notifier).setImperial(imperial);
  }

  Future<void> _onContinue() async {
    final finder = ref.read(shapeFinderProvider);
    if (_leaving || !_complete(finder)) return;
    setState(() => _leaving = true);
    if (_saveToProfile) {
      // Saved to the profile in the background; the estimate doesn't wait.
      ref
          .read(onboardingControllerProvider.notifier)
          .saveMeasurements(finder.cm, imperial: finder.imperial);
    }
    await ref.read(shapeFinderProvider.notifier).estimateFromMeasurements();
    if (!mounted) return;
    await context.pushNamed(ShapeResultScreen.name);
    if (mounted) setState(() => _leaving = false);
  }

  bool _complete(ShapeFinderState finder) =>
      _specs.every((s) => !s.required || finder.cm[s.field] != null);

  @override
  Widget build(BuildContext context) {
    final finder = ref.watch(shapeFinderProvider);
    return ShapeFinderScaffold(
      section: 'Measurements',
      onForward: _complete(finder) ? _onContinue : null,
      bottom: ShapeFinderPrimaryButton(
        label: 'Continue',
        trailing: Icons.arrow_forward,
        onPressed: _complete(finder) ? _onContinue : null,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: ShapeFinderHeading(
                'Quick measurements',
                body:
                    'Use a soft tape over light clothing. Breathe out '
                    'normally.',
              ),
            ),
            const SizedBox(width: 12),
            _UnitToggle(imperial: finder.imperial, onChanged: _setUnit),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.ivoryDim,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const ShapeFinderBadgeIcon(Icons.auto_awesome, size: 32),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'These calibrate your digital mannequin. You’ll only need '
                  'to enter them once.',
                  style: BlueprintText.optionSupport(
                    context,
                  ).copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < _specs.length; i++) ...[
          _MeasureCard(
            index: i + 1,
            spec: _specs[i],
            title: _specs[i].title(finder.set),
            controller: _text[_specs[i].field]!,
            unit: finder.imperial ? 'in' : 'cm',
            valid: finder.cm[_specs[i].field] != null,
            range:
                '${_display(_specs[i].minCm, imperial: finder.imperial)}–'
                '${_display(_specs[i].maxCm, imperial: finder.imperial)}',
            onChanged: (t) => _onChanged(_specs[i], t),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: () => setState(() => _saveToProfile = !_saveToProfile),
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              Checkbox(
                value: _saveToProfile,
                onChanged: (v) => setState(() => _saveToProfile = v ?? false),
                activeColor: AppColors.espressoDark,
              ),
              Expanded(
                child: Text(
                  'Save these values to my private avatar profile',
                  style: BlueprintText.option(context).copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.imperial, required this.onChanged});

  final bool imperial;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget option(String label, bool value) {
      final selected = imperial == value;
      return Semantics(
        selected: selected,
        button: true,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: selected ? AppColors.espressoDark : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: BlueprintText.caption(context).copyWith(
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.white : AppColors.inkSoft,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [option('cm', false), option('in', true)],
      ),
    );
  }
}

class _MeasureCard extends StatelessWidget {
  const _MeasureCard({
    required this.index,
    required this.spec,
    required this.title,
    required this.controller,
    required this.unit,
    required this.valid,
    required this.range,
    required this.onChanged,
  });

  final int index;
  final _Spec spec;
  final String title;
  final TextEditingController controller;
  final String unit;
  final bool valid;

  /// The accepted range in the display unit, e.g. `60–180`.
  final String range;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final caption = BlueprintText.caption(context);
    return ShapeFinderCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.ivoryWarm,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 7,
                  top: 5,
                  child: Text(
                    index.toString().padLeft(2, '0'),
                    style: caption.copyWith(fontSize: 9),
                  ),
                ),
                Center(
                  child: LineGlyph(spec.glyph, size: const Size.square(44)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: BlueprintText.option(
                          context,
                        ).copyWith(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.ivoryHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        spec.required ? 'REQUIRED' : 'OPTIONAL',
                        style: caption.copyWith(
                          fontSize: 9,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(spec.description, style: caption.copyWith(fontSize: 12)),
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  style: BlueprintText.option(
                    context,
                  ).copyWith(fontSize: 18, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.ivoryWarm,
                    // A placeholder, not a value: light and regular weight.
                    hintText: range,
                    hintStyle: BlueprintText.option(context).copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.taupe,
                    ),
                    // The unit stays put whether or not the field has text.
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 14),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            unit,
                            style: caption.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.taupe,
                            ),
                          ),
                          if (valid) ...[
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.check_circle,
                              color: AppColors.sage,
                              size: 20,
                            ),
                          ],
                        ],
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.espresso,
                        width: 1.5,
                      ),
                    ),
                    errorText: controller.text.trim().isNotEmpty && !valid
                        ? 'Enter $range $unit'
                        : null,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showGuide(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.help_outline,
                          size: 16,
                          color: AppColors.espressoDark,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'How to measure',
                          style: caption.copyWith(
                            color: AppColors.espressoDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showGuide(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ivory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How to measure your ${title.toLowerCase()}',
                style: BlueprintText.heading(ctx).copyWith(fontSize: 22),
              ),
              const SizedBox(height: 16),
              MeasurementGuide(bodyPart: spec.field.name),
            ],
          ),
        ),
      ),
    );
  }
}
