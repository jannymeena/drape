import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../models/outfit_reasoning.dart';
import '../today_service.dart';

/// "Why This Outfit Works" sheet. Fetches the real reasoning for [outfitId] via
/// `GET /outfits/{id}/reasoning` — narrative, per-item rationales, the
/// compatibility band, and the headline factors are all server-authored.
class AiReasoningDetailScreen extends ConsumerWidget {
  static const path = '/today/outfit/:id/reasoning';
  static const name = 'ai_reasoning_detail';

  final String outfitId;

  const AiReasoningDetailScreen({super.key, required this.outfitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reasoning = ref.watch(outfitReasoningProvider(outfitId));

    return Scaffold(
      backgroundColor: AppColors.espressoDeep.withValues(alpha: 0.4),
      body: SafeArea(
        top: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => context.pop(),
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.88,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.sand,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  _TitleRow(onClose: () => context.pop()),
                  Flexible(
                    child: reasoning.when(
                      loading: () => const _BodyMessage(
                        child: Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 48),
                            child: CircularProgressIndicator(
                                color: AppColors.espresso),
                          ),
                        ),
                      ),
                      error: (e, _) => _BodyMessage(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            e is ApiException
                                ? e.message
                                : "We couldn't load the styling notes. Please try again.",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      data: (data) => _ReasoningBody(data: data),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      border: Border(top: BorderSide(color: AppColors.ivoryDim)),
                    ),
                    child: DrapeButton(
                      label: 'Got It',
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: AppColors.white,
                        size: 18,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  final VoidCallback onClose;
  const _TitleRow({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Why This Outfit Works',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Material(
            color: AppColors.ivoryDim,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onClose,
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Icons.close, color: AppColors.espresso, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps the loading/error states inside the same scroll padding as the body so
/// the sheet doesn't jump as content resolves.
class _BodyMessage extends StatelessWidget {
  final Widget child;
  const _BodyMessage({required this.child});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: child,
    );
  }
}

class _ReasoningBody extends StatelessWidget {
  final OutfitReasoning data;
  const _ReasoningBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _NarrativeBlock(text: data.fullText),
          if (data.factors.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: data.factors.map((f) => _FactorChip(label: f)).toList(),
            ),
          ],
          if (data.items.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Item by Item',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: AppColors.espresso),
            ),
            const SizedBox(height: 12),
            ...data.items.map(
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ItemRow(item: i),
              ),
            ),
          ],
          if (data.compatibilityScore != null) ...[
            const SizedBox(height: 24),
            _CompatibilityScore(
              score: data.compatibilityScore!,
              label: data.compatibilityLabel,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _NarrativeBlock extends StatelessWidget {
  final String? text;
  const _NarrativeBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55);
    final body = (text == null || text!.trim().isEmpty)
        ? "We don't have a detailed breakdown for this look yet — but the pieces were chosen to work together for the occasion."
        : text!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ivoryDim,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(body, style: base),
    );
  }
}

class _FactorChip extends StatelessWidget {
  final String label;
  const _FactorChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tanFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.espressoDark,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final ReasoningItem item;
  const _ItemRow({required this.item});

  /// Coloured category silhouette (the app's house placeholder) instead of a
  /// bare hanger icon when the item has no photo.
  Widget get _placeholder => GarmentPlaceholder(
        category: item.category ?? '',
        color: garmentColorFromName(item.colorName),
      );

  @override
  Widget build(BuildContext context) {
    final note = item.whyItWorks;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 56,
              child: item.imageUrl == null
                  ? _placeholder
                  : Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: Theme.of(context).textTheme.titleSmall),
                if (note != null && note.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(note, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityScore extends StatelessWidget {
  final int score;
  final String label;
  const _CompatibilityScore({required this.score, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                'Compatibility Score',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: AppColors.espresso),
              ),
            ),
            Text(
              '$score/100',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.sage,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 12,
            backgroundColor: AppColors.sand,
            valueColor: const AlwaysStoppedAnimation(AppColors.sage),
          ),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    );
  }
}
