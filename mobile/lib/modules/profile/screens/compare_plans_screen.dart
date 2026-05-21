import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';

enum _Cadence { monthly, annual }

class ComparePlansScreen extends StatefulWidget {
  static const path = 'compare-plans';
  static const name = 'profile_compare_plans';

  const ComparePlansScreen({super.key});

  @override
  State<ComparePlansScreen> createState() => _ComparePlansScreenState();
}

class _ComparePlansScreenState extends State<ComparePlansScreen> {
  _Cadence _cadence = _Cadence.monthly;

  static const _categories = <_FeatureCategory>[
    _FeatureCategory(
      label: 'WARDROBE MANAGEMENT',
      rows: [
        _FeatureRow('Maximum items', '50 items', 'Unlimited'),
        _FeatureRow('Background removal', null, _check),
      ],
    ),
    _FeatureCategory(
      label: 'AI OUTFIT GENERATION',
      rows: [
        _FeatureRow('Daily suggestions', '3 looks', 'Infinite'),
        _FeatureRow('Event-specific styling', null, _check),
      ],
    ),
    _FeatureCategory(
      label: 'SHOPPING & STYLE ADVISOR',
      rows: [
        _FeatureRow('Personal shopper AI', null, _check),
        _FeatureRow('Style score analysis', null, _check),
      ],
    ),
    _FeatureCategory(
      label: 'DATA & INSIGHTS',
      rows: [
        _FeatureRow('Cost-per-wear tracking', _check, _check),
        _FeatureRow('Usage analytics', _check, _check),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Center(
                    child: Text(
                      'Choose your rhythm.',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Find the plan that fits your style journey. Upgrade or downgrade anytime.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CadenceToggle(
                    cadence: _cadence,
                    onChanged: (c) => setState(() => _cadence = c),
                  ),
                  const SizedBox(height: 20),
                  _PlanColumns(cadence: _cadence),
                  const SizedBox(height: 24),
                  for (final cat in _categories) ...[
                    _CategoryBlock(category: cat),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.espressoDeep,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'Unlock the Virtual Atelier experience with advanced AI',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.brandText,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Have questions?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Our style consultants are here to help you find the perfect rhythm.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton(
                      onPressed: () => debugPrint('compare: contact support'),
                      child: Text(
                        'Contact Support',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.espresso,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ProTrialCta(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const String _check = '✓';

class _FeatureCategory {
  final String label;
  final List<_FeatureRow> rows;
  const _FeatureCategory({required this.label, required this.rows});
}

class _FeatureRow {
  final String label;
  final String? free;
  final String? pro;
  const _FeatureRow(this.label, this.free, this.pro);
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
              'Compare Plans',
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

class _CadenceToggle extends StatelessWidget {
  final _Cadence cadence;
  final ValueChanged<_Cadence> onChanged;
  const _CadenceToggle({required this.cadence, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.tanFixed.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToggleChoice(
              label: 'Monthly',
              selected: cadence == _Cadence.monthly,
              onTap: () => onChanged(_Cadence.monthly),
            ),
            _ToggleChoice(
              label: r'Annual (Save $30)',
              selected: cadence == _Cadence.annual,
              onTap: () => onChanged(_Cadence.annual),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.espresso : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.white : AppColors.inkSoft,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _PlanColumns extends StatelessWidget {
  final _Cadence cadence;
  const _PlanColumns({required this.cadence});

  String get _proPrice =>
      cadence == _Cadence.monthly ? r'$14.99' : r'$149.99';
  String get _proCadence =>
      cadence == _Cadence.monthly ? '/month' : '/year';

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _PlanCard(
            label: 'CURRENT PLAN',
            name: 'Free',
            price: r'$0',
            cadence: 'forever',
            cta: 'Your plan',
            highlighted: false,
            background: AppColors.white,
            foreground: AppColors.ink,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PlanCard(
            label: 'RECOMMENDED',
            name: 'Pro',
            price: _proPrice,
            cadence: _proCadence,
            cta: 'Upgrade to Pro',
            highlighted: true,
            background: AppColors.espresso,
            foreground: AppColors.brandText,
          ),
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String label;
  final String name;
  final String price;
  final String cadence;
  final String cta;
  final bool highlighted;
  final Color background;
  final Color foreground;

  const _PlanCard({
    required this.label,
    required this.name,
    required this.price,
    required this.cadence,
    required this.cta,
    required this.highlighted,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: highlighted
            ? null
            : Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: highlighted ? AppColors.gold : AppColors.taupe,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: foreground,
                ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      )),
              const SizedBox(width: 4),
              Text(cadence,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.7),
                      )),
            ],
          ),
          const SizedBox(height: 12),
          if (highlighted)
            Material(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => debugPrint('compare: upgrade'),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  child: Text(
                    cta,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.espressoDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.tanFixed.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check, color: AppColors.espresso, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    cta,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.espresso,
                          fontWeight: FontWeight.w700,
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

class _CategoryBlock extends StatelessWidget {
  final _FeatureCategory category;
  const _CategoryBlock({required this.category});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.tanFixed.withValues(alpha: 0.4),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: Text(
            category.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.taupe,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < category.rows.length; i++) ...[
                _FeatureRowWidget(row: category.rows[i]),
                if (i < category.rows.length - 1)
                  Divider(
                    height: 1,
                    color: AppColors.taupeSoft.withValues(alpha: 0.3),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FeatureRowWidget extends StatelessWidget {
  final _FeatureRow row;
  const _FeatureRowWidget({required this.row});

  Widget _cell(BuildContext context, String? value) {
    final isCheck = value == _check;
    return Expanded(
      child: Center(
        child: isCheck
            ? const Icon(Icons.check, color: AppColors.sage, size: 18)
            : Text(
                value ?? '—',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: value == null ? AppColors.taupe : AppColors.ink,
                      fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
                    ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              row.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                  ),
            ),
          ),
          _cell(context, row.free),
          _cell(context, row.pro),
        ],
      ),
    );
  }
}

class _ProTrialCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            'Ready to unlock all features?',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Material(
            color: AppColors.espresso,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => debugPrint('compare: start trial'),
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: Center(
                  child: Text(
                    'Start Pro Trial - 7 Days Free',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            r'Cancel anytime. $14.99/month after trial.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
