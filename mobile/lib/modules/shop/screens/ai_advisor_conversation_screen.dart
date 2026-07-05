import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../profile/screens/compare_plans_screen.dart';
import '../models/shop.dart';
import '../shop_service.dart';

/// AI Style Advisor chat (`POST /shop/advisor/ask`). Opens with either an
/// initial [question] (fired immediately, one call per turn) or an existing
/// [conversationId] from history. 429s surface the paywall.
class AiAdvisorConversationScreen extends ConsumerStatefulWidget {
  static const path = 'advisor/conversation';
  static const name = 'shop_advisor_conversation';

  final String? question;
  final String? conversationId;

  const AiAdvisorConversationScreen({
    super.key,
    this.question,
    this.conversationId,
  });

  @override
  ConsumerState<AiAdvisorConversationScreen> createState() =>
      _AiAdvisorConversationScreenState();
}

class _AiAdvisorConversationScreenState
    extends ConsumerState<AiAdvisorConversationScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  List<AdvisorMessage> _messages = const [];
  String? _conversationId;
  String? _pendingQuestion; // rendered as a user bubble while waiting
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _conversationId = widget.conversationId;
    if (widget.conversationId != null) {
      Future.microtask(_loadExisting);
    } else if (widget.question != null && widget.question!.trim().isNotEmpty) {
      Future.microtask(() => _ask(widget.question!.trim()));
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    try {
      final history = await ref.read(shopServiceProvider).advisorHistory();
      final convo =
          history.where((c) => c.id == widget.conversationId).firstOrNull;
      if (convo != null && mounted) {
        setState(() => _messages = convo.messages);
      }
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _ask(String question) async {
    if (_sending) return;
    setState(() {
      _sending = true;
      _pendingQuestion = question;
    });
    try {
      final convo = await ref.read(shopServiceProvider).advisorAsk(
            question,
            conversationId: _conversationId,
          );
      ref.invalidate(advisorHistoryProvider);
      if (!mounted) return;
      setState(() {
        _conversationId = convo.id;
        _messages = convo.messages;
        _pendingQuestion = null;
        _sending = false;
      });
      _scrollToEnd();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _pendingQuestion = null;
        _sending = false;
      });
      if (e.statusCode == 429) {
        _showLimit(e.message);
      } else {
        _showError(e.message);
      }
    }
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _ask(text);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _showLimit(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Upgrade',
          onPressed: () => context.goNamed(ComparePlansScreen.name),
        ),
      ),
    );
  }

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
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                children: [
                  for (final m in _messages)
                    m.role == 'user'
                        ? Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _UserBubble(text: m.content),
                          )
                        : Padding(
                            padding: const EdgeInsets.only(bottom: 20),
                            child: _StylistReply(message: m),
                          ),
                  if (_pendingQuestion != null) ...[
                    _UserBubble(text: _pendingQuestion!),
                    const SizedBox(height: 16),
                  ],
                  if (_sending)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.espresso),
                      ),
                    ),
                  if (_messages.isEmpty && !_sending)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'Ask anything — occasions, pairings, gaps to fill.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
            _InputBar(
              controller: _input,
              enabled: !_sending,
              onSend: _send,
            ),
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
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: AppColors.tanFixed,
          borderRadius: BorderRadius.only(
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

class _StylistReply extends ConsumerWidget {
  final AdvisorMessage message;
  const _StylistReply({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.espressoDeep,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            message.content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.brandText,
                ),
          ),
        ),
        for (final suggestion in message.suggestions) ...[
          const SizedBox(height: 8),
          _SuggestionCard(suggestion: suggestion),
        ],
      ],
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  final AdvisorSuggestion suggestion;
  const _SuggestionCard({required this.suggestion});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the matched catalog product (if any) from the loaded feed.
    final product = ref
        .watch(shopFeedProvider)
        .valueOrNull
        ?.products
        .where((p) => p.id == suggestion.productId)
        .firstOrNull;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.checkroom_outlined,
              color: AppColors.espresso, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(suggestion.name,
                    style: Theme.of(context).textTheme.titleSmall),
                Text(suggestion.reason,
                    style: Theme.of(context).textTheme.bodySmall),
                if (product != null)
                  Text(
                    '${product.brand} · ${product.priceLabel}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.espresso,
                          fontWeight: FontWeight.w700,
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.onSend,
  });

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
            border:
                Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  onSubmitted: (_) => onSend(),
                  textInputAction: TextInputAction.send,
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
              GestureDetector(
                onTap: enabled ? onSend : null,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.espresso,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.send, color: AppColors.white, size: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
