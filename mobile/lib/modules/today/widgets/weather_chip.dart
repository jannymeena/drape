import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/today_dashboard.dart';

/// Today dashboard weather widget — temperature + condition + hint + chevron,
/// plus the source credit when the provider requires one (WeatherKit terms:
/// Apple Weather mark + a link to its data-sources page).
class WeatherChip extends StatelessWidget {
  final String temperature;
  final String condition;
  final String hint;
  final String? location;
  final IconData icon;
  final VoidCallback? onTap;
  final WeatherAttribution? attribution;

  const WeatherChip({
    super.key,
    required this.temperature,
    required this.condition,
    required this.hint,
    this.location,
    this.icon = Icons.cloud_outlined,
    this.onTap,
    this.attribution,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tanFixed.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.espresso, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$temperature • $condition',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.espresso,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (attribution != null) ...[
                      const SizedBox(height: 6),
                      _Attribution(attribution: attribution!),
                    ],
                  ],
                ),
              ),
              if (location != null) ...[
                const SizedBox(width: 8),
                Text(
                  location!.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.inkSoft,
                        letterSpacing: 1.2,
                      ),
                ),
              ] else
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.espresso,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "[ Weather] · Data sources" — the whole row opens the legal page. The
/// mark falls back to the service name as text if the logo can't load.
class _Attribution extends StatelessWidget {
  final WeatherAttribution attribution;
  const _Attribution({required this.attribution});

  Future<void> _openLegal() async {
    final uri = Uri.tryParse(attribution.legalUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.inkSoft,
        );
    return Semantics(
      button: true,
      label: 'Weather data from ${attribution.serviceName}. View data sources.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openLegal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The app has no dark theme and the chip is always light, so the
            // dark-on-light ("light") logo variant is the right one.
            Image.network(
              attribution.logoLightUrl,
              height: 14,
              errorBuilder: (_, _, _) =>
                  Text(attribution.serviceName, style: style),
            ),
            Text('  ·  ', style: style),
            Text(
              'Data sources',
              style: style?.copyWith(decoration: TextDecoration.underline),
            ),
          ],
        ),
      ),
    );
  }
}
