import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

/// Step 1 of the 3-step cancellation flow.
/// Returns the selected reason on Continue, or null if dismissed.
Future<String?> showCancellationReasonSheet(BuildContext context) {
  return showModalBottomSheet<String?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    barrierColor: AppColors.espressoDeep.withValues(alpha: 0.4),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _CancellationReasonSheet(),
  );
}

class _CancellationReasonSheet extends StatefulWidget {
  const _CancellationReasonSheet();

  @override
  State<_CancellationReasonSheet> createState() => _CancellationReasonSheetState();
}

class _CancellationReasonSheetState extends State<_CancellationReasonSheet> {
  static const _reasons = [
    'Too expensive',
    'Not using enough features',
    'Found an alternative',
    'Technical issues',
    'Other',
  ];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.tanFixed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Why are you canceling?',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Help us improve ZOURA',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 20),
            for (int i = 0; i < _reasons.length; i++) ...[
              _ReasonRow(
                label: _reasons[i],
                selected: _selected == i,
                onTap: () => setState(() => _selected = i),
              ),
              if (i < _reasons.length - 1) const SizedBox(height: 10),
            ],
            const SizedBox(height: 24),
            DrapeButton(
              label: 'Continue',
              onPressed: () => Navigator.of(context).pop(_reasons[_selected]),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ReasonRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.tanFixed.withValues(alpha: 0.7) : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.espresso : AppColors.taupeSoft,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.espresso,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
