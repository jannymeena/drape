import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';
import '../../onboarding/screens/shopping_style_screen.dart';
import '../widgets/oauth_buttons.dart';
import '../widgets/password_field.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  static const path = '/auth/signup';
  static const name = 'signup';

  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onCreate() {
    // Phase E will wire AuthService.signUp here.
    debugPrint('signup: ${_emailController.text}');
    context.goNamed(ShoppingStyleScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(title: 'Create Account'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            OAuthButtons(
              onApple: () => debugPrint('signup: apple'),
              onGoogle: () => debugPrint('signup: google'),
            ),
            DrapeTextField(
              label: 'Email address',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),
            PasswordField(controller: _passwordController),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 16, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: Theme.of(context).textTheme.bodySmall,
                      children: const [
                        TextSpan(text: 'Your data is stored securely in Canada. '),
                        TextSpan(text: '🇨🇦'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodySmall,
                children: const [
                  TextSpan(text: 'By continuing, you agree to our '),
                  TextSpan(
                    text: 'Terms',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            DrapeButton(label: 'Create Account', onPressed: _onCreate),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => context.goNamed(LoginScreen.name),
                child: Text.rich(
                  TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium,
                    children: const [
                      TextSpan(text: 'Already have an account?  '),
                      TextSpan(
                        text: 'Sign In',
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
  }
}
