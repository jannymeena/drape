import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../settings_service.dart';
import 'bug_report_success_screen.dart';

class ReportBugScreen extends ConsumerStatefulWidget {
  static const path = 'report-bug';
  static const name = 'profile_report_bug';

  const ReportBugScreen({super.key});

  @override
  ConsumerState<ReportBugScreen> createState() => _ReportBugScreenState();
}

class _ReportBugScreenState extends ConsumerState<ReportBugScreen> {
  String _category = 'Select category...';
  int _frequency = 0;
  bool _submitting = false;
  final _describe = TextEditingController();
  final _steps = TextEditingController();
  static const _freqOptions = ['Every time', 'Sometimes', 'Only once', 'Not sure'];

  @override
  void dispose() {
    _describe.dispose();
    _steps.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final desc = _describe.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the bug.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(settingsServiceProvider).submitSupport(
            kind: 'bug-report',
            subject: _category == 'Select category...' ? null : _category,
            message: desc,
            extra: {
              'frequency': _freqOptions[_frequency],
              if (_steps.text.trim().isNotEmpty) 'steps': _steps.text.trim(),
            },
          );
      if (mounted) context.goNamed(BugReportSuccessScreen.name);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Text('Help us squash bugs 🐛',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 6),
                  Text(
                    'Your feedback helps make ZOURA better for everyone. We respond within 24 hours.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  _Label("WHAT'S BROKEN?"),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.ivoryWarm,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _category,
                        isExpanded: true,
                        icon: const Icon(Icons.keyboard_arrow_down,
                            color: AppColors.taupe),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppColors.ink,
                            ),
                        items: const [
                          DropdownMenuItem(
                              value: 'Select category...',
                              child: Text('Select category...')),
                          DropdownMenuItem(value: 'Scanner', child: Text('Scanner')),
                          DropdownMenuItem(value: 'Outfits', child: Text('Outfits')),
                          DropdownMenuItem(value: 'Sync', child: Text('Sync')),
                          DropdownMenuItem(value: 'Billing', child: Text('Billing')),
                        ],
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Label('DESCRIBE THE BUG'),
                  _BoxField(hint: 'What happened?', lines: 4, controller: _describe),
                  const SizedBox(height: 6),
                  Text(
                    'Tip: Be as specific as possible about what you were doing when the issue occurred.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _Label('STEPS TO REPRODUCE (OPTIONAL)'),
                  _BoxField(hint: '1. Open wardrobe\n2. Click edit...', lines: 3, controller: _steps),
                  const SizedBox(height: 16),
                  _Label('HOW OFTEN DOES THIS HAPPEN?'),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 3.4,
                    children: List.generate(_freqOptions.length, (i) {
                      return _RadioTile(
                        label: _freqOptions[i],
                        selected: _frequency == i,
                        onTap: () => setState(() => _frequency = i),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  _SystemInfoCard(),
                  const SizedBox(height: 16),
                  _Label('SCREENSHOTS (OPTIONAL)'),
                  Row(
                    children: [
                      _UploadTile(),
                      const SizedBox(width: 10),
                      _ScreenshotThumb(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _Label('UPDATE EMAIL'),
                  _BoxField(hint: 'alex.chen@email.com'),
                  const SizedBox(height: 4),
                  Text("We'll update you on the progress of this fix.",
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 20),
                  DrapeButton(
                    label: _submitting ? 'Submitting…' : 'Submit Bug Report',
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
            child: Text('Report a Bug',
                textAlign: TextAlign.center,
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

class _Label extends StatelessWidget {
  final String label;
  const _Label(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

class _RadioTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _RadioTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.espresso : AppColors.taupeSoft,
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.espresso,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.espresso, size: 16),
              const SizedBox(width: 8),
              Text('Auto-Captured System Info',
                  style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _kv(context, 'Device', 'iPhone 14 Pro')),
              Expanded(child: _kv(context, 'OS', 'iOS 17.4.1')),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _kv(context, 'App Version', 'v2.4.0')),
              Expanded(child: _kv(context, 'Storage', '84% Free')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Text.rich(TextSpan(
      style: Theme.of(context).textTheme.bodySmall,
      children: [
        TextSpan(text: '$k: '),
        TextSpan(text: v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ));
  }
}

class _UploadTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => debugPrint('bug: upload screenshot'),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.taupeSoft),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                color: AppColors.espresso, size: 20),
            const SizedBox(height: 4),
            Text('Tap (max 3)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.taupe,
                    )),
          ],
        ),
      ),
    );
  }
}

class _ScreenshotThumb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.ivoryWarm,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.image, color: AppColors.taupeSoft),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.close, color: AppColors.white, size: 12),
          ),
        ),
      ],
    );
  }
}
