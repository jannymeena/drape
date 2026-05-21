import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../widgets/settings_row.dart';
import '../widgets/settings_section.dart';
import 'feature_request_screen.dart';
import 'help_center_hub_screen.dart';
import 'report_bug_screen.dart';

class ContactUsScreen extends StatelessWidget {
  static const path = 'contact';
  static const name = 'profile_contact';

  const ContactUsScreen({super.key});

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
                  _DropdownField(),
                  const SizedBox(height: 14),
                  _FieldLabel('YOUR EMAIL'),
                  _Field(hint: 'alexander.v@atelier.com'),
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
                  _Field(hint: 'How can our stylists assist you today?', lines: 4),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => debugPrint('contact: attach'),
                      icon: const Icon(Icons.attach_file,
                          size: 16, color: AppColors.espresso),
                      label: Text('Attach Screenshot',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.espresso,
                                fontWeight: FontWeight.w700,
                              )),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DrapeButton(
                    label: 'SEND MESSAGE',
                    onPressed: () => debugPrint('contact: send'),
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
          Text('concierge@drape.luxury',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          DrapeButton(
            label: 'Send Email',
            onPressed: () => debugPrint('contact: email'),
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
  const _Field({required this.hint, this.lines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
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
          value: 'General Inquiry',
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.taupe),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.ink,
              ),
          items: const [
            DropdownMenuItem(value: 'General Inquiry', child: Text('General Inquiry')),
            DropdownMenuItem(value: 'Billing', child: Text('Billing')),
            DropdownMenuItem(value: 'Technical', child: Text('Technical')),
            DropdownMenuItem(value: 'Styling', child: Text('Styling')),
          ],
          onChanged: (_) {},
        ),
      ),
    );
  }
}
