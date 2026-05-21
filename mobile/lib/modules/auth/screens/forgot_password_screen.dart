import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const path = '/auth/forgot-password';
  static const name = 'forgot_password';

  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _onSend() {
    // Phase E will wire AuthService.requestPasswordReset here.
    debugPrint('forgot: ${_emailController.text}');
    setState(() => _sent = true);
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
                  ? "We've sent a reset link to ${_emailController.text}. The link expires in 1 hour."
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
              ),
              const SizedBox(height: 24),
              DrapeButton(label: 'Send reset link', onPressed: _onSend),
            ] else ...[
              DrapeButton(
                label: 'Back to sign in',
                onPressed: () => context.goNamed(LoginScreen.name),
              ),
              const SizedBox(height: 12),
              DrapeButton.text(
                label: "Didn't get the email? Resend",
                onPressed: () => debugPrint('forgot: resend'),
              ),
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
