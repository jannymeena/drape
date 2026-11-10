import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/today_dashboard.dart';

enum TodayChipTone {
  /// Mist-blue — weather facts ("8°C, feels 5° · Rain").
  weather,

  /// Warm neutral — the day's plan ("Parents' meeting · Smart casual").
  plan,
}

/// One of the context pills under the Today greeting.
class TodayContextChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final TodayChipTone tone;
  final VoidCallback? onTap;

  const TodayContextChip({
    super.key,
    required this.icon,
    required this.label,
    this.tone = TodayChipTone.weather,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final weather = tone == TodayChipTone.weather;
    final bg = weather ? AppColors.mist : AppColors.ivoryWarm;
    final fg = weather ? AppColors.mistInk : AppColors.ink;
    final iconColor = weather ? AppColors.mistInk : AppColors.espressoDark;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: fg,
                        fontWeight: weather ? FontWeight.w600 : FontWeight.w500,
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

/// "[ Weather] · Data sources" — the source credit the weather provider
/// requires (WeatherKit terms: Apple Weather mark + a link to its data-sources
/// page). The whole row opens the legal page; the mark falls back to the
/// service name as text if the logo can't load.
class WeatherAttributionLine extends StatelessWidget {
  final WeatherAttribution attribution;
  const WeatherAttributionLine({super.key, required this.attribution});

  Future<void> _openLegal() async {
    final uri = Uri.tryParse(attribution.legalUrl);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.taupe,
          letterSpacing: 0.2,
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
            // The app has no dark theme and the page is always light, so the
            // dark-on-light ("light") logo variant is the right one.
            Image.network(
              attribution.logoLightUrl,
              height: 12,
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
