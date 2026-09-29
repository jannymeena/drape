import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Opens an AWIN tracking link in the browser (the click is what earns the
/// affiliate commission). Snackbar when no app can open it.
Future<void> openProductLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  final ok = uri != null && await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the shop.')),
    );
  }
}

/// Corner pill on a garment the user doesn't own yet (AWIN product).
class BuyPill extends StatelessWidget {
  final VoidCallback onTap;
  const BuyPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.espresso,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            'BUY',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.white,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
