import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';
import '../auth_controller.dart';
import '../widgets/password_field.dart';
import 'forgot_password_screen.dart';
import 'login_screen.dart';

/// Sets a new password from the opaque token in the reset email
/// (`/auth/reset-password?token=…`). The token arrives via the route's query
/// parameter — see `router_provider.dart` — which is how the email deep link
/// lands here. A missing token shows the invalid-link state.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  static const path = '/auth/reset-password';
  static const name = 'reset_password';

  const ResetPasswordScreen({super.key, required this.token});

  /// The opaque reset token from the email link, or null when absent/malformed.
  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _done = false;
  String? _errorText;

  bool get _hasToken => (widget.token ?? '').isNotEmpty;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onReset() async {
    if (_submitting) return;

    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (password.isEmpty || confirm.isEmpty) {
      setState(() => _errorText = 'Enter and confirm your new password.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorText = "Passwords don't match.");
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref.read(authControllerProvider.notifier).resetPassword(
            token: widget.token!,
            newPassword: password,
          );
      if (!mounted) return;
      setState(() => _done = true);
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
          children: switch ((_hasToken, _done)) {
            (false, _) => _invalidLink(context),
            (true, true) => _success(context),
            (true, false) => _form(context),
          },
        ),
      ),
    );
  }

  List<Widget> _form(BuildContext context) {
    return [
      Text('Choose a new password',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(
        'Your new password must be at least 8 characters and include a letter and a number.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      PasswordField(
        label: 'New password',
        controller: _passwordController,
        onChanged: (_) => _clearError(),
      ),
      const SizedBox(height: 16),
      DrapeTextField(
        label: 'Confirm new password',
        controller: _confirmController,
        obscureText: true,
        textInputAction: TextInputAction.done,
        errorText: _errorText,
        onChanged: (_) => _clearError(),
      ),
      const SizedBox(height: 24),
      DrapeButton(
        label: 'Reset password',
        loading: _submitting,
        onPressed: _onReset,
      ),
    ];
  }

  List<Widget> _success(BuildContext context) {
    return [
      Text('Password updated',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(
        'Your password has been changed. Please sign in with your new password.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 24),
      DrapeButton(
        label: 'Sign in',
        onPressed: () => context.goNamed(LoginScreen.name),
      ),
    ];
  }

  List<Widget> _invalidLink(BuildContext context) {
    return [
      Text('Link expired or invalid',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text(
        "This password reset link isn't valid anymore. Request a new one to continue.",
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.taupe,
            ),
      ),
      const SizedBox(height: 24),
      DrapeButton(
        label: 'Request a new link',
        onPressed: () => context.goNamed(ForgotPasswordScreen.name),
      ),
      const SizedBox(height: 12),
      DrapeButton.text(
        label: 'Back to sign in',
        onPressed: () => context.goNamed(LoginScreen.name),
      ),
    ];
  }

  void _clearError() {
    if (_errorText != null) setState(() => _errorText = null);
  }
}
