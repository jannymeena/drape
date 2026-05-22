import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';
import '../auth_controller.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  static const path = '/auth/forgot-password';
  static const name = 'forgot_password';

  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  // Dev-only: lets you paste the reset token from the server console (the dev
  // email provider logs it) and jump straight to the reset screen.
  final _devTokenController = TextEditingController();
  bool _sent = false;
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _devTokenController.dispose();
    super.dispose();
  }

  /// Dev shortcut around the (not-yet-wired) email deep link: navigate to the
  /// reset screen with the pasted token as the `?token=` query param.
  void _openResetWithDevToken() {
    final token = _devTokenController.text.trim();
    if (token.isEmpty) return;
    context.goNamed(
      ResetPasswordScreen.name,
      queryParameters: {'token': token},
    );
  }

  Future<void> _onSend() async {
    if (_submitting) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = 'Enter your email address.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(email: email);
      if (!mounted) return;
      setState(() => _sent = true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorText = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorText = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(title: 'Reset password'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            Text(
              _sent ? 'Check your email' : 'Forgot your password?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              _sent
                  ? "We've sent a reset link to ${_emailController.text}. The link expires in 30 minutes."
                  : "Enter your email and we'll send you a link to reset your password.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            if (!_sent) ...[
              DrapeTextField(
                label: 'Email address',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                errorText: _errorText,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              const SizedBox(height: 24),
              DrapeButton(
                label: 'Send reset link',
                loading: _submitting,
                onPressed: _onSend,
              ),
            ] else ...[
              DrapeButton(
                label: 'Back to sign in',
                onPressed: () => context.goNamed(LoginScreen.name),
              ),
              const SizedBox(height: 12),
              DrapeButton.text(
                label: "Didn't get the email? Resend",
                loading: _submitting,
                onPressed: _onSend,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'DEV — paste the reset token from the server console '
                  '(no email is sent in dev).',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.taupe,
                      ),
                ),
                const SizedBox(height: 12),
                DrapeTextField(
                  label: 'Reset token',
                  controller: _devTokenController,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 12),
                DrapeButton.outlined(
                  label: 'Open reset screen',
                  onPressed: _openResetWithDevToken,
                ),
              ],
            ],
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Need help?  ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.taupe,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
