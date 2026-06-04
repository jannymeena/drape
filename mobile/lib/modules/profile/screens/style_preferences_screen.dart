import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/outline_chip.dart';
import '../models/app_settings.dart';
import '../settings_service.dart';

class StylePreferencesScreen extends ConsumerStatefulWidget {
  static const path = 'style-preferences';
  static const name = 'profile_style_preferences';

  const StylePreferencesScreen({super.key});

  @override
  ConsumerState<StylePreferencesScreen> createState() =>
      _StylePreferencesScreenState();
}

class _StylePreferencesScreenState
    extends ConsumerState<StylePreferencesScreen> {
  final _archetypes = <int>{};
  final _palettes = <int>{};
  final _occasions = <String>{};
  double _intensity = 0.5;
  double _formality = 0.5;

  bool _seeded = false;
  bool _saving = false;

  /// Seed selections from the `style_preferences` JSONB blob. We store labels
  /// (not indices) so reordering the option lists never corrupts saved prefs.
  void _seedOnce(AppSettings s) {
    if (_seeded) return;
    _seeded = true;
    final p = s.stylePreferences;
    if (p == null) return;

    final arch = (p['archetypes'] as List?)?.cast<String>() ?? const [];
    for (var i = 0; i < _archetypeLabels.length; i++) {
      if (arch.contains(_archetypeLabels[i].$1)) _archetypes.add(i);
    }
    final pal = (p['palettes'] as List?)?.cast<String>() ?? const [];
    for (var i = 0; i < _paletteLabels.length; i++) {
      if (pal.contains(_paletteLabels[i].$1)) _palettes.add(i);
    }
    _occasions.addAll((p['occasions'] as List?)?.cast<String>() ?? const []);
    _intensity = (p['intensity'] as num?)?.toDouble() ?? _intensity;
    _formality = (p['formality'] as num?)?.toDouble() ?? _formality;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final blob = <String, dynamic>{
      'archetypes': _archetypes.map((i) => _archetypeLabels[i].$1).toList(),
      'palettes': _palettes.map((i) => _paletteLabels[i].$1).toList(),
      'occasions': _occasions.toList(),
      'intensity': _intensity,
      'formality': _formality,
    };
    try {
      await ref
          .read(settingsServiceProvider)
          .updateSettings({'style_preferences': blob});
      if (mounted) context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't save — check your connection."),
        ),
      );
    }
  }

  static const _archetypeLabels = [
    ('Minimal', Icons.landscape_outlined),
    ('Classic', Icons.diamond_outlined),
    ('Streetwear', Icons.directions_walk),
    ('Smart Casual', Icons.weekend_outlined),
    ('Bold', Icons.flash_on_outlined),
    ('Athletic', Icons.fitness_center_outlined),
  ];

  static const _paletteLabels = [
    ('Neutrals', 'Timeless base', [
      Color(0xFFF1EDE8),
      Color(0xFFD5C3BB),
      Color(0xFF1C1C19),
    ]),
    ('Earth Tones', 'Organic warmth', [
      Color(0xFFB05D40),
      Color(0xFF53643A),
      Color(0xFFE9B499),
    ]),
    ('Monochromes', 'High contrast', [
      Color(0xFF000000),
      Color(0xFF707070),
      Color(0xFFE3E3E3),
    ]),
    ('Pastels', 'Soft & light', [
      Color(0xFFFAD0CC),
      Color(0xFFEFE2A6),
      Color(0xFFD0E7E1),
    ]),
    ('Saturated', 'Vibrant pops', [
      Color(0xFFD32F2F),
      Color(0xFF1565C0),
      Color(0xFF2E7D32),
    ]),
    ('Mixed', 'Eclectic fusion', [
      Color(0xFFE9B499),
      Color(0xFFBE3636),
      Color(0xFF7E553F),
    ]),
  ];

  static const _occasionList = [
    'Work', 'WFH', 'Casual errands', 'Gym',
    'Evenings out', 'Date nights', 'Formal',
    'Travel', 'Outdoors', 'Weekend',
    'School', 'Creative',
  ];

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsProvider);
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onBack: () => context.pop(),
              onSave: _saving ? null : _save,
            ),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (e, _) => _ErrorState(
                  message: e is ApiException
                      ? e.message
                      : "We couldn't load your style preferences.",
                  onRetry: () => ref.invalidate(settingsProvider),
                ),
                data: (s) {
                  _seedOnce(s);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                  _SectionLabel('STYLE ARCHETYPE'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 2.6,
                    children: List.generate(_archetypeLabels.length, (i) {
                      final selected = _archetypes.contains(i);
                      return _SelectableTile(
                        icon: _archetypeLabels[i].$2,
                        label: _archetypeLabels[i].$1,
                        selected: selected,
                        onTap: () => setState(() {
                          if (!_archetypes.add(i)) _archetypes.remove(i);
                        }),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('COLOR PALETTE'),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.6,
                    children: List.generate(_paletteLabels.length, (i) {
                      final p = _paletteLabels[i];
                      return _PaletteTile(
                        label: p.$1,
                        description: p.$2,
                        swatches: p.$3,
                        selected: _palettes.contains(i),
                        onTap: () => setState(() {
                          if (!_palettes.add(i)) _palettes.remove(i);
                        }),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('STYLE INTENSITY'),
                  const SizedBox(height: 6),
                  Text('HOW BOLD?',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.taupe,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: 4),
                  _BipolarSlider(
                    leftLabel: 'CONSERVATIVE',
                    rightLabel: 'STATEMENT',
                    value: _intensity,
                    onChanged: (v) => setState(() => _intensity = v),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('OCCASIONS'),
                  const SizedBox(height: 4),
                  Text(
                    'Where I dress for most',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in _occasionList)
                        OutlineChip(
                          label: o,
                          selected: _occasions.contains(o),
                          onPressed: () => setState(() {
                            if (!_occasions.add(o)) _occasions.remove(o);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _BipolarSlider(
                    leftLabel: 'RELAXED',
                    rightLabel: 'DRESSED UP',
                    value: _formality,
                    onChanged: (v) => setState(() => _formality = v),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.espressoDeep,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      '"Style is a way to say who you are without having to speak."',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.brandText,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onSave;
  const _Header({required this.onBack, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Style Preferences',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          TextButton(
            onPressed: onSave,
            child: Text(
              'Save',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.taupe,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _SelectableTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SelectableTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.espresso : AppColors.taupeSoft,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.espresso, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              if (selected)
                const Icon(Icons.check_circle,
                    color: AppColors.espresso, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaletteTile extends StatelessWidget {
  final String label;
  final String description;
  final List<Color> swatches;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteTile({
    required this.label,
    required this.description,
    required this.swatches,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.espresso : AppColors.taupeSoft,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (final c in swatches) ...[
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppColors.taupeSoft.withValues(alpha: 0.5)),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ],
              ),
              const Spacer(),
              Text(label, style: Theme.of(context).textTheme.titleSmall),
              Text(description,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _BipolarSlider extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final double value;
  final ValueChanged<double> onChanged;

  const _BipolarSlider({
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(leftLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.taupe,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    )),
            Text(rightLabel,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.taupe,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    )),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            activeTrackColor: AppColors.espresso,
            inactiveTrackColor: AppColors.tanFixed,
            thumbColor: AppColors.espresso,
          ),
          child: Slider(value: value, onChanged: onChanged),
        ),
      ],
    );
  }
}
