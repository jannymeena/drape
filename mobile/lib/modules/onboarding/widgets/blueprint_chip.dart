import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'blueprint_choice_card.dart';
import 'blueprint_scaffold.dart';

/// The Style Blueprint's chip: a pill choice, from the step 6 mockup.
/// Picked, it fills espresso with a white semibold label and a tick;
/// otherwise it's white with a fine warm border (so it shows on white cards
/// too). One look for every step's chips.
class BlueprintChip extends StatelessWidget {
  const BlueprintChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.expand = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Before the label, e.g. a colour dot.
  final Widget? leading;

  /// Fill the slot it's given (a grid cell), label centred, rather than
  /// hugging the label at 40 pt tall.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (leading case final l?) ...[l, const SizedBox(width: 8)],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BlueprintText.optionSupport(context).copyWith(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? AppColors.white : AppColors.ink,
            ),
          ),
        ),
        if (selected) ...[
          const SizedBox(width: 6),
          const Icon(Icons.check, size: 15, color: AppColors.white),
        ],
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.espresso : AppColors.white,
        elevation: selected ? 2 : 0,
        shadowColor: AppColors.black.withValues(alpha: 0.3),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? AppColors.espresso : BlueprintChoiceCard.line,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: expand
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: content,
                )
              : Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: content,
                ),
        ),
      ),
    );
  }
}
