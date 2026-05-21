import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'ai_advisor_conversation_screen.dart';

/// Past AI advisor conversations. No dedicated mockup — designed consistent
/// with the module from the "HISTORY" affordances in the initial screen.
class AiAdvisorHistoryScreen extends StatelessWidget {
  static const path = 'advisor/history';
  static const name = 'shop_advisor_history';

  const AiAdvisorHistoryScreen({super.key});

  static const _history = <_Conversation>[
    _Conversation(
      title: 'Traditional Tamil wedding guest look',
      snippet: '3 curated looks · navy blazer pairing',
      when: '2h ago',
    ),
    _Conversation(
      title: 'Wedding in Tuscany',
      snippet: 'Linen suiting for a warm outdoor ceremony',
      when: 'Yesterday',
    ),
    _Conversation(
      title: 'Work conference outfits',
      snippet: '5-day capsule, smart-casual',
      when: '3 days ago',
    ),
    _Conversation(
      title: 'Sophisticated date night ensemble',
      snippet: 'Monochrome with a textured layer',
      when: 'Last week',
    ),
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
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: _history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _ConversationRow(
                  conversation: _history[i],
                  onTap: () =>
                      context.goNamed(AiAdvisorConversationScreen.name),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Conversation {
  final String title;
  final String snippet;
  final String when;
  const _Conversation({
    required this.title,
    required this.snippet,
    required this.when,
  });
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text('Conversation History',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
          ),
        ],
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final _Conversation conversation;
  final VoidCallback onTap;
  const _ConversationRow({required this.conversation, required this.onTap});

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
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.ivoryWarm,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.auto_awesome,
                    color: AppColors.gold, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(conversation.snippet,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(conversation.when,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.taupe,
                      )),
            ],
          ),
        ),
      ),
    );
  }
}
