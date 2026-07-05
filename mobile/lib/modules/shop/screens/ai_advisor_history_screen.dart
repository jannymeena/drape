import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../shop_service.dart';
import 'ai_advisor_conversation_screen.dart';

/// Past AI advisor conversations. No dedicated mockup — designed consistent
/// with the module from the "HISTORY" affordances in the initial screen.
class AiAdvisorHistoryScreen extends ConsumerWidget {
  static const path = 'advisor/history';
  static const name = 'shop_advisor_history';

  const AiAdvisorHistoryScreen({super.key});

  static String _ago(DateTime when) {
    final delta = DateTime.now().difference(when);
    if (delta.inMinutes < 60) return '${delta.inMinutes.clamp(1, 59)}m ago';
    if (delta.inHours < 24) return '${delta.inHours}h ago';
    if (delta.inDays == 1) return 'Yesterday';
    return '${delta.inDays} days ago';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(advisorHistoryProvider);
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (e, _) => Center(
                  child: Text(
                    e is ApiException
                        ? e.message
                        : "We couldn't load your conversations.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                data: (conversations) => conversations.isEmpty
                    ? Center(
                        child: Text(
                          'No conversations yet — ask the advisor anything.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        itemCount: conversations.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ConversationRow(
                          conversation: _Conversation(
                            title: conversations[i].title,
                            snippet: conversations[i].messages.isEmpty
                                ? ''
                                : conversations[i].messages.last.content,
                            when: _ago(conversations[i].updatedAt),
                          ),
                          onTap: () => context.goNamed(
                            AiAdvisorConversationScreen.name,
                            queryParameters: {'id': conversations[i].id},
                          ),
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
