import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/session_store.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';
import '../../today/screens/today_dashboard_screen.dart';
import '../widgets/oauth_buttons.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  static const path = '/auth/login';
  static const name = 'login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    // Phase E will wire AuthService.login here. For now persist a mock session
    // so subsequent launches skip straight to Today.
    debugPrint('login: ${_emailController.text}');
    await SessionStore.setLoggedIn(true);
    if (mounted) context.goNamed(TodayDashboardScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(),
      // Content is centered vertically when there's spare room, and becomes
      // scrollable once the keyboard reduces the available height.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 28),
                    OAuthButtons(
                      onApple: () => debugPrint('login: apple'),
                      onGoogle: () => debugPrint('login: google'),
                    ),
                    DrapeTextField(
                      label: 'Email address',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    DrapeTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () =>
                            context.goNamed(ForgotPasswordScreen.name),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot password?',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.espresso,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DrapeButton(label: 'Sign In', onPressed: _onSignIn),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () => context.goNamed(SignUpScreen.name),
                        child: Text.rich(
                          TextSpan(
                            style: Theme.of(context).textTheme.bodyMedium,
                            children: const [
                              TextSpan(text: 'No account?  '),
                              TextSpan(
                                text: 'Create one free',
                                style: TextStyle(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
