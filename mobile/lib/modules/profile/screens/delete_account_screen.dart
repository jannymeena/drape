import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../auth/auth_controller.dart';
import '../settings_service.dart';

/// "Type DELETE" safety pattern (case-sensitive).
/// The destructive button is disabled until the user types exactly `DELETE`.
class DeleteAccountScreen extends ConsumerStatefulWidget {
  static const path = 'delete-account';
  static const name = 'profile_delete_account';

  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _controller = TextEditingController();
  bool _enabled = false;
  bool _deleting = false;

  /// Permanently delete on the server, then clear the local session — the
  /// router's auth gate then bounces to Welcome.
  Future<void> _delete() async {
    setState(() => _deleting = true);
    try {
      await ref.read(settingsServiceProvider).deleteAccount();
      await ref.read(authControllerProvider.notifier).logout();
      // No navigation needed: clearing the session redirects to Welcome.
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  static const _confirmString = 'DELETE';

  static const _erased = [
    'Personal Wardrobe & Moodboards',
    'Outfit History & Styling Analytics',
    'AI Measurements & Fit Profiles',
    'Pro Subscription Benefits',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final ok = _controller.text == _confirmString;
      if (ok != _enabled) setState(() => _enabled = ok);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.taupeSoft.withValues(alpha: 0.4),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.warning_amber_rounded,
                        color: AppColors.error, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Delete Your\nAccount?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'This action is permanent and cannot be undone. All your curated data will be removed from the ZOURA servers.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.ivoryWarm,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATA TO BE ERASED:',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.taupe,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 10),
                        for (final item in _erased) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 3),
                                child: Icon(Icons.close,
                                    color: AppColors.error, size: 14),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  item,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'TYPE $_confirmString TO CONFIRM',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.taupe,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    style: Theme.of(context).textTheme.bodyLarge,
                    decoration: InputDecoration(
                      hintText: 'Type $_confirmString to confirm',
                      hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppColors.taupe,
                          ),
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.taupeSoft),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: AppColors.taupeSoft),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: _enabled ? AppColors.error : AppColors.espresso,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Material(
                    color: _enabled
                        ? AppColors.error
                        : AppColors.error.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: (_enabled && !_deleting) ? _delete : null,
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: Center(
                          child: Text(
                            _deleting
                                ? 'Deleting…'
                                : 'I Understand, Delete My Account',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ZOURA Atelier · Security Protocol 8.2',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
