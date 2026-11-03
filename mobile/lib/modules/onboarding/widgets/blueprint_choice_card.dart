import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'blueprint_scaffold.dart';

/// Pick-any (a tick box) or pick-one (a radio).
enum ChoiceControl { checkbox, radio }

/// The Style Blueprint's list-style choice: a bordered card with its control
/// on the left, a title, and optionally a line of detail, an icon tile, a
/// trailing badge and a footer (step 7's brand examples). Picked, it takes an
/// espresso border, a warm fill and a filled control. One look for every
/// step's choice lists, from the step 7 mockup.
class BlueprintChoiceCard extends StatelessWidget {
  const BlueprintChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.control = ChoiceControl.radio,
    this.detail,
    this.icon,
    this.trailing,
    this.footer,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ChoiceControl control;

  /// A line under the title.
  final String? detail;

  /// A small tile between the control and the title.
  final IconData? icon;

  /// At the right end, e.g. a badge.
  final Widget? trailing;

  /// Under the title row, lined up with the title.
  final Widget? footer;

  // The step 7 mockup's tones.
  static const ink = Color(0xFF2A1810);
  static const soft = Color(0xFF6B5848);
  static const line = Color(0xFFE8D8C8);

  /// Picked fill: a deeper sand behind tick boxes, a lighter cream behind
  /// radios.
  static const checkedFill = Color(0xFFF5E8D8);
  static const radioFill = Color(0xFFFDF5EE);

  static const _controlGap = 14.0;

  /// How far the title sits in from the card's padding: the control and its
  /// gap (and the icon tile's, when there is one).
  double get _titleIndent =>
      (control == ChoiceControl.checkbox ? 22 : 20) +
      _controlGap +
      (icon == null ? 0 : 32 + 12);

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    final isCheckbox = control == ChoiceControl.checkbox;
    final titleColor = selected && !isCheckbox
        ? AppColors.espresso
        : (selected ? ink : AppColors.ink);
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: body.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        if (detail case final d?) ...[
          const SizedBox(height: 2),
          Text(d, style: body.copyWith(fontSize: 12, height: 1.6, color: soft)),
        ],
      ],
    );
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: !isCheckbox,
      child: Material(
        color: selected
            ? (isCheckbox ? checkedFill : radioFill)
            : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.espresso : line,
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: detail == null
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: detail == null ? 0 : 1),
                      child: isCheckbox
                          ? _TickBox(checked: selected)
                          : _Radio(selected: selected),
                    ),
                    const SizedBox(width: _controlGap),
                    if (icon case final i?) ...[
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.white
                              : AppColors.ivoryWarm,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(i, size: 19, color: AppColors.espresso),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(child: title),
                    if (trailing case final t?) ...[
                      const SizedBox(width: 12),
                      t,
                    ],
                  ],
                ),
                if (footer case final f?) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: EdgeInsets.only(left: _titleIndent),
                    child: f,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TickBox extends StatelessWidget {
  const _TickBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

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
