import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

class AiReasoningDetailScreen extends StatelessWidget {
  static const path = '/today/outfit/:id/reasoning';
  static const name = 'ai_reasoning_detail';

  final String outfitId;

  const AiReasoningDetailScreen({super.key, required this.outfitId});

  static const _items = <_ReasoningItem>[
    _ReasoningItem(
      name: 'Navy Linen Shirt',
      note: 'Cool undertone complements your palette.',
      imageUrl:
          'https://images.unsplash.com/photo-1602810318383-e386cc2a3ccf?w=200',
    ),
    _ReasoningItem(
      name: 'Terracotta Trousers',
      note: 'Adds a sophisticated pop of color.',
      imageUrl:
          'https://images.unsplash.com/photo-1551803091-e20673f15770?w=200',
    ),
    _ReasoningItem(
      name: 'Leather Loafers',
      note: 'Classic footwear for a polished look.',
      imageUrl:
          'https://images.unsplash.com/photo-1542838686-37da4a9fd1b3?w=200',
    ),
    _ReasoningItem(
      name: 'Silver Watch',
      note: 'Subtle accessory to tie the look together.',
      imageUrl:
          'https://images.unsplash.com/photo-1524805444758-089113d48a6d?w=200',
    ),
  ];

  @override
  Widget build(BuildContext context) {
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
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
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
                  Padding(
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
                            onTap: () => context.pop(),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.close,
                                  color: AppColors.espresso, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _NarrativeBlock(),
                          const SizedBox(height: 24),
                          Text(
                            'Item by Item',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: AppColors.espresso),
                          ),
                          const SizedBox(height: 12),
                          ..._items.map(
                            (i) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ItemRow(item: i),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _CompatibilityScore(score: 87),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.ivoryDim),
                      ),
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

class _NarrativeBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55);
    final bold = TextStyle(
      fontWeight: FontWeight.w700,
      color: AppColors.espresso,
      fontSize: base?.fontSize,
      height: base?.height,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ivoryDim,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            const TextSpan(text: 'This outfit works on three levels: '),
            TextSpan(text: 'Color harmony', style: bold),
            const TextSpan(text: ' (cool navy balances warm terracotta), '),
            TextSpan(text: 'occasion appropriateness', style: bold),
            const TextSpan(
                text:
                    ' (blazer projects authority for client meetings), and '),
            TextSpan(text: 'wardrobe rotation', style: bold),
            const TextSpan(
                text:
                    " (you haven't worn these trousers in 6 weeks — time to bring them back)."),
          ],
        ),
      ),
    );
  }
}

class _ReasoningItem {
  final String name;
  final String note;
  final String imageUrl;
  const _ReasoningItem({
    required this.name,
    required this.note,
    required this.imageUrl,
  });
}

class _ItemRow extends StatelessWidget {
  final _ReasoningItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
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
            child: Container(
              width: 56,
              height: 56,
              color: AppColors.ivory,
              child: Image.network(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.checkroom_outlined,
                  color: AppColors.taupeSoft,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(item.note,
                    style: Theme.of(context).textTheme.bodySmall),
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
  const _CompatibilityScore({required this.score});

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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.espresso,
                    ),
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
        const SizedBox(height: 8),
        Text(
          'High match for your scheduled 2:00 PM presentation.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
        ),
      ],
    );
  }
}
