import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';

class EmailPasswordSettingsScreen extends StatefulWidget {
  static const path = 'email-password';
  static const name = 'profile_email_password';

  const EmailPasswordSettingsScreen({super.key});

  @override
  State<EmailPasswordSettingsScreen> createState() =>
      _EmailPasswordSettingsScreenState();
}

class _EmailPasswordSettingsScreenState
    extends State<EmailPasswordSettingsScreen> {
  bool _twoFactor = true;

  static const _sessions = [
    ('MacBook Pro 16"', 'Paris, France · Chrome', 'NOW'),
    ('iPhone 15 Pro', 'Paris, France · App', '2H AGO'),
    ('iPad Air', 'London, UK · Safari', 'YESTERDAY'),
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
                  _Card(
                    title: 'Email Address',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('alex.chen@email.com',
                                      style: Theme.of(context).textTheme.bodyLarge),
                                  const SizedBox(height: 6),
                                  _VerifiedBadge(),
                                ],
                              ),
                            ),
                            _PillButton(
                              label: 'Change Email',
                              onTap: () => debugPrint('email: change'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "We'll send a verification link to your new address if you decide to update it.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    title: 'Password',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('• • • • • • • •',
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            color: AppColors.taupe,
                                            letterSpacing: 6,
                                          )),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Last changed: March 15, 2026',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            _PillButton(
                              label: 'Change Password',
                              onTap: () => debugPrint('password: change'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Choose a strong password that you don't use on other websites for maximum security.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    title: 'Two-Factor Authentication (2FA)',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add an extra layer of security to your account. Each time you sign in, you\'ll need your password and a verification code.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text('Enable 2FA via SMS',
                                  style: Theme.of(context).textTheme.titleSmall),
                            ),
                            Switch(
                              value: _twoFactor,
                              onChanged: (v) => setState(() => _twoFactor = v),
                              activeThumbColor: AppColors.espresso,
                            ),
                          ],
                        ),
                        if (_twoFactor) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Enabled: Your account is protected.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.sage,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    title: 'Recent Sign-In Activity',
                    background: AppColors.ivoryWarm,
                    child: Column(
                      children: [
                        for (final s in _sessions)
                          _SessionRow(device: s.$1, location: s.$2, when: s.$3),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'View All Activity →',
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppColors.espresso,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                      ],
                    ),
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
              'Email & Password',
              textAlign: TextAlign.center,
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

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  final Color? background;

  const _Card({required this.title, required this.child, this.background});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background ?? AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.sageDim,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check, color: AppColors.sage, size: 12),
          const SizedBox(width: 4),
          Text(
            'VERIFIED',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.sageContent,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: AppColors.espresso),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.espresso,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final String device;
  final String location;
  final String when;
  const _SessionRow({
    required this.device,
    required this.location,
    required this.when,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.laptop_mac,
                color: AppColors.espresso, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device, style: Theme.of(context).textTheme.titleSmall),
                Text(location, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          Text(
            when,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.taupe,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
