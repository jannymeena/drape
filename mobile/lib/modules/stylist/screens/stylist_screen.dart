import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../shop/screens/ai_advisor_initial_screen.dart';

/// The Stylist tab. Placeholder until its design lands: points at the AI
/// Advisor (Shop) so the tab is useful in the meantime.
class StylistScreen extends StatelessWidget {
  static const path = '/stylist';
  static const name = 'stylist';

  const StylistScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 60,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Stylist',
                    style: text.headlineMedium?.copyWith(
                      color: AppColors.espressoDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: AppColors.ivoryWarm,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome_outlined,
                            color: AppColors.espressoDark, size: 32),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Your stylist is on the way',
                        textAlign: TextAlign.center,
                        style: text.headlineSmall?.copyWith(
                          color: AppColors.espressoDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Soon you can chat about outfits, occasions and what '
                        'to wear with what you own. Until then, ask the AI '
                        'Advisor.',
                        textAlign: TextAlign.center,
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: () =>
                            context.goNamed(AiAdvisorInitialScreen.name),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.espresso,
                          foregroundColor: AppColors.white,
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: const Text('Ask the AI Advisor'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
