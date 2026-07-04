import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../settings_service.dart';
import 'feature_request_success_screen.dart';

class FeatureRequestScreen extends ConsumerStatefulWidget {
  static const path = 'feature-request';
  static const name = 'profile_feature_request';

  const FeatureRequestScreen({super.key});

  @override
  ConsumerState<FeatureRequestScreen> createState() =>
      _FeatureRequestScreenState();
}

class _FeatureRequestScreenState extends ConsumerState<FeatureRequestScreen> {
  int _priority = 0;
  bool _submitting = false;
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _useCase = TextEditingController();
  static const _priorities = ['Nice to have', 'Important', 'Critical'];

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _useCase.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final desc = _desc.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the feature.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(settingsServiceProvider).submitSupport(
            kind: 'feature-request',
            subject: _name.text.trim().isEmpty ? null : _name.text.trim(),
            message: desc,
            extra: {
              'priority': _priorities[_priority],
              if (_useCase.text.trim().isNotEmpty) 'use_case': _useCase.text.trim(),
            },
          );
      if (mounted) context.goNamed(FeatureRequestSuccessScreen.name);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  static const _topFeatures = <_Feature>[
    _Feature(
      status: 'UNDER REVIEW',
      statusColor: AppColors.gold,
      name: 'Multi-user Wardrobe Sharing',
      votes: 124,
      quote: 'Ability to share specific wardrobe pieces with a partner or stylist for collaborative planning.',
    ),
    _Feature(
      status: 'PLANNED',
      statusColor: AppColors.sage,
      name: 'Seasonal Planning Calendar',
      votes: 98,
      quote: 'A drag-and-drop calendar view to schedule outfits for upcoming trips and events.',
    ),
    _Feature(
      status: 'NEW',
      statusColor: AppColors.espresso,
      name: 'AR Try-On Integration',
      votes: 82,
      quote: 'Visualizing existing wardrobe items on a live camera feed using augmented reality.',
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text('Shape the future of DRAPE 💡',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Your vision helps us build the ultimate digital atelier. Suggest features, vote on ideas, and watch your styling experience evolve.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.tanFixed.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.star_outline,
                            color: AppColors.gold, size: 18),
                        const SizedBox(width: 10),
                        Text("Pro members' requests are prioritized",
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text('Top Requested Features',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      Text('COMMUNITY\nFAVORITES',
                          textAlign: TextAlign.right,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.taupe,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final f in _topFeatures) ...[
                    _FeatureCard(feature: f),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 8),
                  Text('Submit a Request',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text("Tell us what you're missing from the atelier.",
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 14),
                  _Label('CATEGORY'),
                  _Dropdown(),
                  const SizedBox(height: 14),
                  _Label('FEATURE NAME'),
                  _BoxField(hint: 'e.g. Virtual Shoe Closet', controller: _name),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _Label('DESCRIPTION'),
                      Text('0 / 500',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.taupe,
                              )),
                    ],
                  ),
                  _BoxField(hint: 'How should this work?', lines: 4, controller: _desc),
                  const SizedBox(height: 14),
                  _Label('USE CASE (OPTIONAL)'),
                  _BoxField(hint: 'When would you use this?', lines: 2, controller: _useCase),
                  const SizedBox(height: 14),
                  _Label('PRIORITY LEVEL'),
                  Row(
                    children: List.generate(_priorities.length, (i) {
                      return Padding(
                        padding: EdgeInsets.only(right: i < 2 ? 8 : 0),
                        child: _PriorityPill(
                          label: _priorities[i],
                          selected: _priority == i,
                          onTap: () => setState(() => _priority = i),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),
                  DrapeButton(
                    label: _submitting ? 'Submitting…' : 'Submit Feature Request',
                    onPressed: _submitting ? null : _submit,
                    leading: const Icon(Icons.send, color: AppColors.white, size: 16),
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

class _Feature {
  final String status;
  final Color statusColor;
  final String name;
  final int votes;
  final String quote;
  const _Feature({
    required this.status,
    required this.statusColor,
    required this.name,
    required this.votes,
    required this.quote,
  });
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
            child: Text('Feature Requests',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.tanFixed,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: AppColors.espresso, size: 16),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final _Feature feature;
  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.status,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: feature.statusColor,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(feature.name,
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              Column(
                children: [
                  Text('${feature.votes}',
                      style: Theme.of(context).textTheme.titleLarge),
                  Text('VOTES',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.taupe,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          )),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${feature.quote}"',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: AppColors.inkSoft,
                ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () => debugPrint('upvote ${feature.name}'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.thumb_up_outlined,
                      color: AppColors.espresso, size: 14),
                  const SizedBox(width: 4),
                  Text('Upvote',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.espresso,
                            fontWeight: FontWeight.w700,
                          )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.taupe,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _BoxField extends StatelessWidget {
  final String hint;
  final int lines;
  final TextEditingController? controller;
  const _BoxField({required this.hint, this.lines = 1, this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: lines,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.taupe,
            ),
        filled: true,
        fillColor: AppColors.ivoryWarm,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: 'Visual Interface',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.taupe),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.ink,
              ),
          items: const [
            DropdownMenuItem(value: 'Visual Interface', child: Text('Visual Interface')),
            DropdownMenuItem(value: 'AI Styling', child: Text('AI Styling')),
            DropdownMenuItem(value: 'Wardrobe', child: Text('Wardrobe')),
            DropdownMenuItem(value: 'Shopping', child: Text('Shopping')),
          ],
          onChanged: (_) {},
        ),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PriorityPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.sageDim : AppColors.ivoryWarm,
            borderRadius: BorderRadius.circular(8),
            border: selected
                ? Border.all(color: AppColors.sage)
                : null,
          ),
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: selected ? AppColors.sageContent : AppColors.inkSoft,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

