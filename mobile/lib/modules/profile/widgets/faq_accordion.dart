import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

class FaqItem {
  final String question;
  final String answer;
  const FaqItem(this.question, this.answer);
}

class FaqGroup {
  final String title;
  final IconData icon;
  final List<FaqItem> items;
  const FaqGroup({required this.title, required this.icon, required this.items});
}

/// Expandable FAQ group card. Starts expanded if [initiallyExpanded].
class FaqAccordion extends StatefulWidget {
  final FaqGroup group;
  final bool initiallyExpanded;

  const FaqAccordion({
    super.key,
    required this.group,
    this.initiallyExpanded = false,
  });

  @override
  State<FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<FaqAccordion> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(widget.group.icon, color: AppColors.espresso, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.group.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.taupe,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final item in widget.group.items) ...[
                    const Divider(height: 1, color: AppColors.taupeSoft),
                    const SizedBox(height: 12),
                    Text(
                      item.question,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.answer,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
