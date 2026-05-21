import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';
import 'wardrobe_setup_screen.dart';

class ManualEntryScreen extends StatelessWidget {
  static const path = '/onboarding/manual-entry';
  static const name = 'manual_entry';

  const ManualEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(title: 'Enter Measurements'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'All at once',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Prefer to type everything in one go? Fill in what you know — leave the rest blank, you can finish later.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            const _MField(label: 'Height (cm)'),
            const SizedBox(height: 16),
            const _MField(label: 'Weight (kg) — optional'),
            const SizedBox(height: 16),
            const _MField(label: 'Chest / Bust (cm)'),
            const SizedBox(height: 16),
            const _MField(label: 'Waist (cm)'),
            const SizedBox(height: 16),
            const _MField(label: 'Hips (cm)'),
            const SizedBox(height: 16),
            const _MField(label: 'Inseam (cm)'),
            const SizedBox(height: 16),
            const _MField(label: 'Shoulders (cm)'),
            const SizedBox(height: 28),
            DrapeButton(
              label: 'Save Measurements',
              onPressed: () => context.goNamed(WardrobeSetupScreen.name),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Switch to step-by-step in Settings → Your DRAPE Profile.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MField extends StatelessWidget {
  final String label;
  const _MField({required this.label});

  @override
  Widget build(BuildContext context) {
    return DrapeTextField(
      label: label,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }
}
