import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'settings_screen.dart';

class BugReportSuccessScreen extends StatelessWidget {
  static const path = 'report-bug/success';
  static const name = 'profile_bug_success';

  const BugReportSuccessScreen({super.key});

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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.sageDim,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check_circle_outline,
                    color: AppColors.sage, size: 44),
              ),
              const SizedBox(height: 20),
              Text(
                'Bug Report Submitted!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: Theme.of(context).textTheme.bodyMedium,
                  children: const [
                    TextSpan(
                        text:
                            "Thanks for helping us improve ZOURA. We'll investigate and email you at "),
                    TextSpan(
                      text: 'alex.chen@email.com',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' with updates.'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '#BUG-2026-0234',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 160,
                  width: double.infinity,
                  color: AppColors.ivoryWarm,
                  alignment: Alignment.center,
                  child: const Icon(Icons.checkroom,
                      color: AppColors.taupeSoft, size: 64),
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
                          'BACK TO SETTINGS',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'ZOURA',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.taupe,
                      letterSpacing: 4,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
