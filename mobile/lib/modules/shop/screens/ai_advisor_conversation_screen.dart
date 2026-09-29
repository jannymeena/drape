import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../profile/screens/compare_plans_screen.dart';
import '../models/shop.dart';
import '../shop_service.dart';
import '../widgets/advisor_measurement_banner.dart';
import '../../../shared/widgets/buy_pill.dart';
import '../../../shared/widgets/zoura_header.dart';

/// AI Style Advisor chat (`POST /shop/advisor/ask`). Opens with either an
/// initial [question] (fired immediately, one call per turn) or an existing
/// [conversationId] from history. Stylist replies carry up to 3 looks of real
/// products with Buy links. A 429 swaps the input for the upgrade card.
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
  bool _limitReached = false;

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
      final convo = await ref
          .read(shopServiceProvider)
          .advisorConversation(widget.conversationId!);
      if (!mounted) return;
      setState(() => _messages = convo.messages);
      _scrollToEnd();
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
      // Length only — never the question text (free-form user input).
      ref.read(analyticsProvider).capture(
        AnalyticsEvents.aiStyleAdvisorQuestionAsked,
        {'question_length': question.length},
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
        _showLimit();
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

  void _showLimit() {
    ref
        .read(analyticsProvider)
        .capture(AnalyticsEvents.aiAdvisorLimitReached);
    setState(() => _limitReached = true);
    _scrollToEnd();
  }

  void _upgrade() {
    ref.read(analyticsProvider).capture(
      AnalyticsEvents.upgradeTapped,
      {'source': 'advisor_limit'},
    );
    context.goNamed(ComparePlansScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            NestedHeader(title: 'AI Advisor', onBack: () => context.pop()),
            const AdvisorMeasurementBanner(),
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
            if (_limitReached)
              _LimitCard(onUpgrade: _upgrade)
            else
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

class _StylistReply extends StatelessWidget {
  final AdvisorMessage message;
  const _StylistReply({required this.message});

  @override
  Widget build(BuildContext context) {
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
            Text('ZOURA STYLIST',
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
        if (message.looks.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Looks(looks: message.looks),
        ],
      ],
    );
  }
}

/// Look 1 expanded; the rest as collapsed rows that expand in its place.
class _Looks extends StatefulWidget {
  final List<AdvisorLook> looks;
  const _Looks({required this.looks});

  @override
  State<_Looks> createState() => _LooksState();
}

class _LooksState extends State<_Looks> {
  int _open = 0;

  @override
  Widget build(BuildContext context) {
    final looks = widget.looks;
    return Column(
      children: [
        for (var i = 0; i < looks.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          i == _open
              ? _LookCard(look: looks[i], index: i, count: looks.length)
              : _LookRow(
                  look: looks[i],
                  index: i,
                  onTap: () => setState(() => _open = i),
                ),
        ],
      ],
    );
  }
}

class _LookCard extends StatelessWidget {
  final AdvisorLook look;
  final int index;
  final int count;
  const _LookCard({required this.look, required this.index, required this.count});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LOOK ${index + 1} OF $count',
            style: textTheme.labelSmall?.copyWith(
              color: AppColors.gold,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text(look.name, style: textTheme.titleLarge)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.ivoryWarm,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  look.totalLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final item in look.items) ...[
            _ItemRow(item: item),
            const SizedBox(height: 12),
          ],
          if (look.note.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tanFixed.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline,
                      color: AppColors.espresso, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      look.note,
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.espressoDark),
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

class _ItemRow extends StatelessWidget {
  final AdvisorLookItem item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 52,
            height: 52,
            color: AppColors.ivoryWarm,
            child: item.imageUrl.isEmpty
                ? const Icon(Icons.checkroom_outlined, color: AppColors.taupeSoft)
                : CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const Icon(
                        Icons.checkroom_outlined,
                        color: AppColors.taupeSoft),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall),
              Text(item.brand,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.taupe,
                    fontStyle: FontStyle.italic,
                  )),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(item.priceLabel,
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (item.productUrl.isNotEmpty) ...[
          const SizedBox(width: 10),
          BuyPill(onTap: () => openProductLink(context, item.productUrl)),
        ],
      ],
    );
  }
}

class _LookRow extends StatelessWidget {
  final AdvisorLook look;
  final int index;
  final VoidCallback onTap;
  const _LookRow({required this.look, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: AppColors.ivoryWarm,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Text((index + 1).toString().padLeft(2, '0'),
                  style: textTheme.labelMedium?.copyWith(color: AppColors.taupe)),
              const SizedBox(width: 12),
              Expanded(child: Text(look.name, style: textTheme.titleMedium)),
              Text(look.totalLabel,
                  style: textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              const Icon(Icons.expand_more, color: AppColors.taupe),
            ],
          ),
        ),
      ),
    );
  }
}

/// Replaces the input once the weekly question limit is hit (429).
class _LimitCard extends StatelessWidget {
  final VoidCallback onUpgrade;
  const _LimitCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.tanFixed.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unlock Unlimited Styling Advice', style: textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              "You've used this week's questions. Upgrade to ZOURA Pro for "
              'unlimited questions, or ask again after your weekly reset.',
              style: textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: onUpgrade,
                child: const Text('Upgrade to Pro'),
              ),
            ),
          ],
        ),
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
