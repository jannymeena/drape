import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';
import '../../onboarding/onboarding_controller.dart';
import '../../onboarding/resume_route_map.dart';
import '../../today/screens/today_dashboard_screen.dart';
import '../auth_controller.dart';
import '../widgets/oauth_buttons.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  static const path = '/auth/login';
  static const name = 'login';

  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSignIn() async {
    if (_submitting) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorText = 'Enter your email and password.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(authControllerProvider.notifier)
          .loginWithEmail(email: email, password: password);
      if (!mounted) return;
      // Resolve where to land from the backend status (same as the splash boot),
      // which also seeds the onboarding draft so a resumed flow is prefilled with
      // what the user already saved. Completed users land on Today; everyone else
      // resumes at the step they left off — not back at step 1. A status fetch
      // failure shouldn't trap a just-authenticated user, so default to Today.
      try {
        final status = await ref
            .read(onboardingControllerProvider.notifier)
            .loadAndHydrate();
        if (!mounted) return;
        context.goNamed(
          status.onboardingCompleted || isOnboardingDone(status.nextStep)
              ? TodayDashboardScreen.name
              : routeForNextStep(status.nextStep),
        );
      } on ApiException {
        if (mounted) context.goNamed(TodayDashboardScreen.name);
      }
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
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    DrapeTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      errorText: _errorText,
                      onChanged: (_) {
                        if (_errorText != null) {
                          setState(() => _errorText = null);
                        }
                      },
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
                    DrapeButton(
                      label: 'Sign In',
                      loading: _submitting,
                      onPressed: _onSignIn,
                    ),
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
