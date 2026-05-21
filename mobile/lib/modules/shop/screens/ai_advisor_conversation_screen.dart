import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';

/// AI Style Advisor conversation (merges the 3 Tamil-wedding mockup scroll
/// variants + the consultation view). Shows a user question, the stylist's
/// intro, expandable "look" cards, recent questions, and a follow-up input.
class AiAdvisorConversationScreen extends StatelessWidget {
  static const path = 'advisor/conversation';
  static const name = 'shop_advisor_conversation';

  const AiAdvisorConversationScreen({super.key});

  static const _items = [
    ('Mulberry Silk Kurta', 'Fabindia Collective', r'$120'),
    ('Tapered Cream Chinos', 'Modern Fit', r'$45'),
    ('Leather Mojari Loafers', 'Handcrafted Tan', r'$20'),
  ];

  static const _suggestions = [
    'Tamil wedding outfit for a guest',
    'Beach holiday outfit for warm weather',
    'Professional office look for meetings',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                children: [
                  _UserBubble(
                    text:
                        'I need the best outfit for an Indian Tamil traditional wedding as a male guest. I have a navy blazer already.',
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: AppColors.espresso,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.auto_awesome,
                            color: AppColors.gold, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Text('DRAPE STYLIST',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.espresso,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _LookCard(items: _items),
                  const SizedBox(height: 12),
                  _CollapsedLook(title: 'Royal Silk Fusion', price: r'~$240'),
                  const SizedBox(height: 8),
                  _CollapsedLook(title: 'Modern Minimalia', price: r'~$155'),
                  const SizedBox(height: 24),
                  Text('RECENT QUESTIONS',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.taupe,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in _suggestions) _SuggestionChip(label: s),
                    ],
                  ),
                ],
              ),
            ),
            _InputBar(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text('Drape AI Advisor',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
          ),
          const Icon(Icons.settings_outlined, color: AppColors.espresso),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.tanFixed.withValues(alpha: 0.6),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
          ),
        ),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _LookCard extends StatelessWidget {
  final List<(String, String, String)> items;
  const _LookCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.espressoDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '"For a Tamil traditional wedding as a guest, you want rich jewel tones (deep burgundy, forest green, royal blue, or gold). Formal silhouette… Here are 3 curated looks."',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.brandText,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LOOK 1 OF 3',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        )),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('Classic Guest',
                        style: Theme.of(context).textTheme.titleLarge),
                    const Spacer(),
                    Text(r'~$185',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.espresso,
                              fontWeight: FontWeight.w700,
                            )),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    color: AppColors.ivoryWarm,
                    alignment: Alignment.center,
                    child: const Icon(Icons.person,
                        color: AppColors.taupeSoft, size: 64),
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in items) ...[
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.ivoryWarm,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.checkroom_outlined,
                            color: AppColors.taupeSoft, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.$1,
                                style: Theme.of(context).textTheme.titleSmall),
                            Text(item.$2,
                                style: Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                      Text(item.$3,
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.tanFixed.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          color: AppColors.espresso, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The burgundy pairs well with your navy blazer already in your wardrobe.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Material(
                    color: AppColors.espresso,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => debugPrint('advisor: view all 3 items'),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('VIEW ALL 3 ITEMS',
                                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: AppColors.white,
                                        letterSpacing: 1.2,
                                        fontWeight: FontWeight.w700,
                                      )),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward,
                                  color: AppColors.white, size: 14),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollapsedLook extends StatelessWidget {
  final String title;
  final String price;
  const _CollapsedLook({required this.title, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.expand_more, color: AppColors.taupe),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          Text(price,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  )),
        ],
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  const _SuggestionChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _InputBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Ask a follow-up...',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.taupe,
                        ),
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.espresso,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: AppColors.white, size: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
