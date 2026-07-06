import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../../auth/auth_controller.dart';
import '../../auth/auth_service.dart';
import '../profile_service.dart';

// Decisions 2026-07-07 vs the mockup: the 2FA card is absent (2FA is cut for
// v1) and so is the "Recent Sign-In Activity" card (the backend keeps no
// session log — showing fabricated devices would be misleading). Re-add
// either if the backing feature ships.
class EmailPasswordSettingsScreen extends ConsumerStatefulWidget {
  static const path = 'email-password';
  static const name = 'profile_email_password';

  const EmailPasswordSettingsScreen({super.key});

  @override
  ConsumerState<EmailPasswordSettingsScreen> createState() =>
      _EmailPasswordSettingsScreenState();
}

class _EmailPasswordSettingsScreenState
    extends ConsumerState<EmailPasswordSettingsScreen> {
  bool _busy = false;

  /// Prompts for a new address, then `PATCH /users/{id}` — the change is
  /// immediate (own-JWT identity is the user id; there is no verification
  /// round-trip in v1). A 409 (`email_taken`) surfaces as the error text.
  Future<void> _changeEmail(String userId, String currentEmail) async {
    final controller = TextEditingController(text: currentEmail);
    final newEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: const Text('Change email'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(hintText: 'you@example.com'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newEmail == null || newEmail.isEmpty || newEmail == currentEmail) {
      return;
    }
    if (!newEmail.contains('@') || !newEmail.contains('.')) {
      _snack('Enter a valid email address.');
      return;
    }
    setState(() => _busy = true);
    try {
      final user = await ref.read(profileServiceProvider).updateProfile(
            userId: userId,
            email: newEmail,
          );
      ref.read(authControllerProvider.notifier).applyCurrentUser(user);
      if (!mounted) return;
      showDrapeToast(context, 'Email updated.');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// There is no logged-in change-password endpoint — password changes ride
  /// the reset flow: confirm, then `POST /auth/forgot-password` for the
  /// signed-in address (the email carries the reset link).
  Future<void> _changePassword(String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.ivory,
        title: const Text('Change password'),
        content: Text(
          "We'll email a password-reset link to $email. Follow it to set "
          'your new password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(authServiceProvider).requestPasswordReset(email: email);
      if (!mounted) return;
      showDrapeToast(context, 'Reset link sent — check your inbox.');
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: userAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      e is ApiException
                          ? e.message
                          : 'Could not load your account.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                data: (user) => ListView(
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
                                child: Text(
                                  user.email,
                                  style:
                                      Theme.of(context).textTheme.bodyLarge,
                                ),
                              ),
                              _PillButton(
                                label: 'Change Email',
                                onTap: _busy
                                    ? null
                                    : () => _changeEmail(user.id, user.email),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Changes take effect immediately — use the new '
                            'address at your next sign-in.',
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
                                child: Text(
                                  '• • • • • • • •',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: AppColors.taupe,
                                        letterSpacing: 6,
                                      ),
                                ),
                              ),
                              _PillButton(
                                label: 'Change Password',
                                onTap: _busy
                                    ? null
                                    : () => _changePassword(user.email),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            "Choose a strong password that you don't use on "
                            'other websites for maximum security.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
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

class _PillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
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
