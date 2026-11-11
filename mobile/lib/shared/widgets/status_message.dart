import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Centred empty / error message: icon in a warm circle, title, body, and an
/// optional outlined action ("Try again").
class StatusMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;

  const StatusMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.ivoryWarm,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: AppColors.espresso),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: text.titleMedium?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: text.bodySmall),
          if (action != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onAction, child: Text(action!)),
          ],
        ],
      ),
    );
  }
}
