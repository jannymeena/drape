import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/app_settings.dart';
import '../settings_service.dart';

// Names match the backend `theme` literals (`light` | `dark` | `auto`).
enum _Theme { light, dark, auto }

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  static const path = 'appearance';
  static const name = 'profile_appearance';

  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState
    extends ConsumerState<AppearanceSettingsScreen> {
  _Theme _theme = _Theme.light;
  // No backend field yet — local/cosmetic (persist-only round wires theme only).
  double _textSize = 0.5;
  int _accentIndex = 0;
  int _iconIndex = 0;

  bool _seeded = false;

  void _seedOnce(AppSettings s) {
    if (_seeded) return;
    _seeded = true;
    _theme = _Theme.values.firstWhere(
      (t) => t.name == s.theme,
      orElse: () => _Theme.light,
    );
  }

  /// Optimistically selects [theme] and persists it; reverts on failure.
  void _selectTheme(_Theme theme) {
    if (theme == _theme) return;
    final prev = _theme;
    setState(() => _theme = theme);
    () async {
      try {
        await ref
            .read(settingsServiceProvider)
            .updateSettings({'theme': theme.name});
      } catch (e) {
        if (!mounted) return;
        setState(() => _theme = prev);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException
                ? e.message
                : "Couldn't save — check your connection."),
          ),
        );
      }
    }();
  }

  static const _themes = [
    (
      _Theme.light,
      'Light',
      'Warm ivory background · Best in bright spaces',
      AppColors.ivory,
    ),
    (
      _Theme.dark,
      'Dark',
      'Warm espresso background · Easy on eyes at night',
      AppColors.espressoDeep,
    ),
    (
      _Theme.auto,
      'Auto (System)',
      'Follows your device setting automatically',
      null,
    ),
  ];

  static const _accents = [
    ('Espresso', AppColors.espresso),
    ('Sage', AppColors.sage),
    ('Gold', AppColors.gold),
    ('Terracotta', Color(0xFFB05D40)),
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
            _Header(onBack: () => context.pop()),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (e, _) => _ErrorState(
                  message: e is ApiException
                      ? e.message
                      : "We couldn't load your appearance settings.",
                  onRetry: () => ref.invalidate(settingsProvider),
                ),
                data: (s) {
                  _seedOnce(s);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                  _SectionLabel('COLOR THEME'),
                  const SizedBox(height: 10),
                  for (final t in _themes) ...[
                    _ThemeCard(
                      theme: t.$1,
                      label: t.$2,
                      description: t.$3,
                      thumbnailColor: t.$4,
                      selected: _theme == t.$1,
                      onTap: () => _selectTheme(t.$1),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 14),
                  _SectionLabel('TEXT SIZE'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.taupeSoft.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('Default',
                                style: Theme.of(context).textTheme.titleSmall),
                            const Spacer(),
                            Text(
                              'Aa',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            activeTrackColor: AppColors.espresso,
                            inactiveTrackColor: AppColors.tanFixed,
                            thumbColor: AppColors.espresso,
                          ),
                          child: Slider(
                            value: _textSize,
                            onChanged: (v) => setState(() => _textSize = v),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Smaller',
                                style: Theme.of(context).textTheme.bodySmall),
                            Text('Larger',
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                        const Divider(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Your outfit for today →',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('ACCENT COLOR'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      for (int i = 0; i < _accents.length; i++)
                        _ColorSwatch(
                          label: _accents[i].$1,
                          color: _accents[i].$2,
                          selected: _accentIndex == i,
                          onTap: () => setState(() => _accentIndex = i),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('APP ICON'),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _IconChoice(
                        label: 'Default',
                        background: AppColors.espresso,
                        text: 'D',
                        textColor: AppColors.white,
                        selected: _iconIndex == 0,
                        onTap: () => setState(() => _iconIndex = 0),
                      ),
                      _IconChoice(
                        label: 'Dark',
                        background: AppColors.black,
                        text: 'ZOURA',
                        textColor: AppColors.gold,
                        selected: _iconIndex == 1,
                        onTap: () => setState(() => _iconIndex = 1),
                      ),
                      _IconChoice(
                        label: 'Cream',
                        background: AppColors.tanFixed,
                        text: 'ZOURA',
                        textColor: AppColors.espressoDark,
                        selected: _iconIndex == 2,
                        onTap: () => setState(() => _iconIndex = 2),
                      ),
                    ],
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
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Appearance',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 48),
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

class _ThemeCard extends StatelessWidget {
  final _Theme theme;
  final String label;
  final String description;
  final Color? thumbnailColor;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.label,
    required this.description,
    required this.thumbnailColor,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.espresso : AppColors.taupeSoft,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: thumbnailColor != null
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: [0, 0.5, 0.5, 1],
                          colors: [
                            AppColors.ivory,
                            AppColors.ivory,
                            AppColors.espressoDeep,
                            AppColors.espressoDeep,
                          ],
                        ),
                  color: thumbnailColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(description,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              _RadioMark(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  final bool selected;
  const _RadioMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: selected ? AppColors.espresso : AppColors.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, color: AppColors.white, size: 14)
          : null,
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.espresso : Colors.transparent,
                width: 2,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: AppColors.white, size: 22)
                : null,
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _IconChoice extends StatelessWidget {
  final String label;
  final Color background;
  final String text;
  final Color textColor;
  final bool selected;
  final VoidCallback onTap;

  const _IconChoice({
    required this.label,
    required this.background,
    required this.text,
    required this.textColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.espresso : Colors.transparent,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: text.length > 1 ? 11 : 24,
                letterSpacing: text.length > 1 ? 1.4 : 0,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
