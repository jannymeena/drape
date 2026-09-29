import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../profile/screens/edit_measurements_screen.dart';
import '../shop_service.dart';

/// "Complete measurements for better fit suggestions — Update →" strip on the
/// AI Advisor screens. Only while measurements are incomplete (the shop feed
/// carries the flag); hidden while that's loading or failed.
class AdvisorMeasurementBanner extends ConsumerWidget {
  const AdvisorMeasurementBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final complete = ref.watch(shopFeedProvider).valueOrNull?.measurementsComplete;
    if (complete != false) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.tanFixed.withValues(alpha: 0.5),
      child: InkWell(
        onTap: () => context.goNamed(EditMeasurementsScreen.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.lightbulb_outline,
                  color: AppColors.espresso, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Complete measurements for better fit suggestions',
                  style: textTheme.bodySmall
                      ?.copyWith(color: AppColors.espressoDark),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Update →',
                style: textTheme.labelMedium?.copyWith(
                  color: AppColors.espresso,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
