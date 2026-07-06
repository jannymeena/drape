import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'ai_advisor_conversation_screen.dart';
import 'ai_advisor_history_screen.dart';
import 'wishlist_screen.dart';

class AiAdvisorInitialScreen extends StatelessWidget {
  static const path = 'advisor';
  static const name = 'shop_advisor';

  const AiAdvisorInitialScreen({super.key});

  static const _historyChips = ['Wedding in Tuscany', 'Work conference outfits'];

  static const _prompts = [
    'Traditional Tamil wedding guest look',
    'Beach holiday outfit for warm weather',
    'Modern office wardrobe refresh',
    'Sophisticated date night ensemble',
    'Formal graduation ceremony attire',
    'Technical hiking trip gear',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onBack: () => context.pop(),
              onFavorites: () => context.goNamed(WishlistScreen.name),
              onHistory: () => context.goNamed(AiAdvisorHistoryScreen.name),
            ),
            const _MeasurementBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.ivoryWarm,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.auto_awesome,
                          color: AppColors.gold, size: 30),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Ask your AI stylist anything.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Text('What do you need to dress for?',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  Text('HISTORY',
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
                      for (final h in _historyChips)
                        _HistoryChip(
                          label: h,
                          onTap: () => context.goNamed(
                            AiAdvisorConversationScreen.name,
                            queryParameters: {'q': h},
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.7,
                    children: [
                      for (final p in _prompts)
                        _PromptCard(
                          label: p,
                          onTap: () => context.goNamed(
                            AiAdvisorConversationScreen.name,
                            queryParameters: {'q': p},
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _InputBar(
              onSend: (question) => context.goNamed(
                AiAdvisorConversationScreen.name,
                queryParameters: {'q': question},
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onFavorites;
  final VoidCallback onHistory;
  const _Header({
    required this.onBack,
    required this.onFavorites,
    required this.onHistory,
  });

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
          IconButton(
            icon: const Icon(Icons.favorite_border, color: AppColors.espresso),
            onPressed: onFavorites,
          ),
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.espresso),
            onPressed: onHistory,
          ),
        ],
      ),
    );
  }
}

class _MeasurementBanner extends StatelessWidget {
  const _MeasurementBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.tanFixed.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.lightbulb_outline, color: AppColors.espresso, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Complete measurements for better fit suggestions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.espressoDark,
                    )),
          ),
        ],
      ),
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _HistoryChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: AppColors.taupeSoft.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PromptCard({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.ink,
                        )),
              ),
              const Icon(Icons.chevron_right, color: AppColors.taupe, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _InputBar extends StatefulWidget {
  final ValueChanged<String> onSend;
  const _InputBar({required this.onSend});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSend(text);
  }

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
              const Icon(Icons.auto_awesome, color: AppColors.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _submit(),
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'What do you need to dress for?',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.taupe,
                        ),
                  ),
                ),
              ),
              const Icon(Icons.mic_none, color: AppColors.taupe, size: 20),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _submit,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.espresso,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_upward,
                      color: AppColors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
