import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../settings_service.dart';
import '../widgets/settings_row.dart';
import '../widgets/settings_section.dart';
import 'feature_request_screen.dart';
import 'help_center_hub_screen.dart';
import 'report_bug_screen.dart';

class ContactUsScreen extends ConsumerStatefulWidget {
  static const path = 'contact';
  static const name = 'profile_contact';

  /// Subject preselected by the privacy screen's "Correct Your Data" row
  /// (PIPEDA right to correction) — must be one of [subjects].
  static const privacySubject = 'Privacy & My Data';

  static const subjects = [
    'General Inquiry',
    'Billing',
    'Technical',
    'Styling',
    privacySubject,
  ];

  /// Optional deep-link subject (`?subject=…`); ignored when not in
  /// [subjects].
  final String? initialSubject;

  const ContactUsScreen({super.key, this.initialSubject});

  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen> {
  final _message = TextEditingController();
  final _email = TextEditingController();
  late String _subject;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _subject = ContactUsScreen.subjects.contains(widget.initialSubject)
        ? widget.initialSubject!
        : ContactUsScreen.subjects.first;
  }

  @override
  void dispose() {
    _message.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final message = _message.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message.')),
      );
      return;
    }
    setState(() => _submitting = true);
    final email = _email.text.trim();
    try {
      await ref.read(settingsServiceProvider).submitSupport(
            kind: 'contact',
            subject: _subject,
            message: message,
            // The backend replies to the account email by default; an
            // explicit reply-to is a free-form extra.
            extra: email.isEmpty ? null : {'reply_to': email},
          );
      if (!mounted) return;
      showDrapeToast(context, "Message sent — we'll be in touch.");
      context.pop();
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
                  Text('How can we help?',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('We typically respond within 12 hours',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  _EmailSupportCard(),
                  const SizedBox(height: 16),
                  _LiveChatCard(),
                  const SizedBox(height: 24),
                  Text('Send us a message',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  _FieldLabel('SUBJECT'),
                  _DropdownField(
                    value: _subject,
                    onChanged: (v) => setState(() => _subject = v),
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('YOUR EMAIL'),
                  _Field(
                    hint: 'Reply-to (optional — defaults to your account)',
                    controller: _email,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _FieldLabel('MESSAGE'),
                      Text('0 / 1000',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.taupe,
                              )),
                    ],
                  ),
                  _Field(
                    hint: 'How can our stylists assist you today?',
                    lines: 4,
                    controller: _message,
                  ),
                  // The mockup's "Attach Screenshot" is intentionally absent:
                  // the support API has no attachment field (needs backend
                  // work if the product wants it). Screenshots go via email.
                  const SizedBox(height: 12),
                  DrapeButton(
                    label: _submitting ? 'Sending…' : 'SEND MESSAGE',
                    onPressed: _submitting ? null : _submit,
                  ),
                  const SizedBox(height: 24),
                  Text('Other ways to reach us',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  SettingsSection(
                    rows: [
                      SettingsRow(
                        icon: Icons.help_outline,
                        label: 'Help Center',
                        subtitle: 'Browse our guides',
                        onTap: () => context.goNamed(HelpCenterHubScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.bug_report_outlined,
                        label: 'Report a Bug',
                        subtitle: 'Help us improve',
                        onTap: () => context.goNamed(ReportBugScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.lightbulb_outline,
                        label: 'Feature Request',
                        subtitle: 'Share your ideas',
                        onTap: () => context.goNamed(FeatureRequestScreen.name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.close, color: AppColors.ink, size: 18),
                      SizedBox(width: 20),
                      Icon(Icons.camera_alt_outlined,
                          color: AppColors.ink, size: 18),
                    ],
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
            child: Text(
              'Support',
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
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

class _EmailSupportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.mail_outline,
                color: AppColors.espresso, size: 20),
          ),
          const SizedBox(height: 10),
          Text('Email Support', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'RESPONSE TIMES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.taupe,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text.rich(TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: const [
              TextSpan(text: 'Pro: '),
              TextSpan(text: '2 Hours', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          )),
          Text.rich(TextSpan(
            style: Theme.of(context).textTheme.bodyMedium,
            children: const [
              TextSpan(text: 'Free: '),
              TextSpan(text: '24 Hours', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          )),
          const SizedBox(height: 10),
          Text('concierge@zoura.style',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          DrapeButton(
            label: 'Send Email',
            onPressed: () => launchUrl(
              Uri(scheme: 'mailto', path: 'concierge@zoura.style'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveChatCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.sageDim,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.chat_bubble_outline,
                    color: AppColors.sage, size: 18),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'PRO ONLY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.white,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text('Live Chat', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.circle, color: AppColors.sage, size: 8),
              const SizedBox(width: 6),
              Text('Stylists Online Now',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.sage,
                        fontWeight: FontWeight.w600,
                      )),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Available Mon-Fri, 9am - 6pm EST for instant styling consultations.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('Start Live Chat',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.taupe,
                    )),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.tanFixed.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    color: AppColors.espresso, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upgrade to Pro to unlock real-time access to our master tailors and stylists.',
                    style: Theme.of(context).textTheme.bodySmall,
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

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);

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

class _Field extends StatelessWidget {
  final String hint;
  final int lines;
  final TextEditingController? controller;
  const _Field({required this.hint, this.lines = 1, this.controller});

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

class _DropdownField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _DropdownField({required this.value, required this.onChanged});

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
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.taupe),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.ink,
              ),
          items: [
            for (final s in ContactUsScreen.subjects)
              DropdownMenuItem(value: s, child: Text(s)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
