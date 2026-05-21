import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'feature_request_screen.dart';
import 'settings_screen.dart';

class FeatureRequestSuccessScreen extends StatelessWidget {
  static const path = 'feature-request/success';
  static const name = 'profile_feature_success';

  const FeatureRequestSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sageDim.withValues(alpha: 0.35),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            children: [
              const Spacer(),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.lightbulb,
                        color: AppColors.gold, size: 36),
                  ),
                  Positioned(
                    top: -6,
                    right: -10,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.sageDim,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, color: AppColors.sage, size: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Thanks for Your Idea!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: const [
                    TextSpan(text: "We've successfully received your suggestion for "),
                    TextSpan(
                      text: '"Virtual Fabric Swatches"',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    TextSpan(
                        text:
                            ". Our design team reviews all creative submissions during our monthly review cycle to ensure we maintain the atelier's premium standard."),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.taupeSoft),
              const SizedBox(height: 8),
              Text(
                "You can upvote this feature in the 'Popular Requests' section to increase its priority.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.taupe,
                    ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: Material(
                  color: AppColors.espresso,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => context.goNamed(SettingsScreen.name),
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      height: 56,
                      child: Center(
                        child: Text(
                          'Back to Settings',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => context.goNamed(FeatureRequestScreen.name),
                child: Text(
                  'View Popular Requests',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
