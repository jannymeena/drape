import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';
import '../../auth/auth_controller.dart';
import '../../auth/models/current_user.dart';
import '../../wardrobe/image_pick.dart';
import '../profile_service.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  static const path = 'edit';
  static const name = 'profile_edit';

  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  // Name, email, phone, gender, age range and location all persist via
  // `UserUpdate`; the photo via `POST /profile/avatar/upload`. Only the styling
  // chips remain UI-only.
  static const _genderOptions = [
    'Male',
    'Female',
    'Non-binary',
    'Prefer not to say',
  ];
  static const _ageOptions = ['18-24', '25-34', '35-44', '45-54', '55+'];

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  String _gender = 'Male';
  String _ageRange = '25-34';

  bool _prefilled = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  /// Pick + upload a new avatar photo, then push the refreshed identity so the
  /// header re-renders. Shares the `/profile/avatar/upload` path with onboarding.
  Future<void> _pickAvatar(CurrentUser? user) async {
    if (user == null) return;
    final picked = await pickWardrobeImage(context);
    if (picked == null || !mounted) return;
    setState(() => _uploadingPhoto = true);
    try {
      final updated =
          await ref.read(profileServiceProvider).uploadAvatar(picked);
      ref.read(authControllerProvider.notifier).applyCurrentUser(updated);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  /// Populate the form from `/users/me` once it resolves (one-shot, so it
  /// doesn't clobber the user's in-progress edits on rebuild). Dropdown values
  /// only adopt a stored value if it's a known option (else keep the default).
  void _prefill(CurrentUser user) {
    if (_prefilled) return;
    _prefilled = true;
    _name.text = user.displayName;
    _email.text = user.email;
    _phone.text = user.phone ?? '';
    _location.text = user.location ?? '';
    if (user.gender != null && _genderOptions.contains(user.gender)) {
      _gender = user.gender!;
    }
    if (user.ageRange != null && _ageOptions.contains(user.ageRange)) {
      _ageRange = user.ageRange!;
    }
  }

  /// Sends only the changed fields via `PATCH /users/{id}`. If nothing changed,
  /// just closes. On success the new identity is pushed into [AuthController] so
  /// the profile header reflects it; failures (e.g. an email already in use)
  /// surface as a SnackBar.
  Future<void> _save(CurrentUser user) async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) {
      _toast('Name cannot be empty.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _toast('Enter a valid email address.');
      return;
    }
    final phone = _phone.text.trim();
    final location = _location.text.trim();

    final displayName = name != user.displayName ? name : null;
    final newEmail = email != user.email ? email : null;
    final newPhone = phone != (user.phone ?? '') ? phone : null;
    final newLocation = location != (user.location ?? '') ? location : null;
    final newGender = _gender != user.gender ? _gender : null;
    final newAgeRange = _ageRange != user.ageRange ? _ageRange : null;
    if (displayName == null &&
        newEmail == null &&
        newPhone == null &&
        newLocation == null &&
        newGender == null &&
        newAgeRange == null) {
      context.pop();
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await ref.read(profileServiceProvider).updateProfile(
            userId: user.id,
            displayName: displayName,
            email: newEmail,
            phone: newPhone,
            location: newLocation,
            gender: newGender,
            ageRange: newAgeRange,
          );
      ref.read(authControllerProvider.notifier).applyCurrentUser(updated);
      if (!mounted) return;
      _toast('Profile updated.');
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(e.message);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user != null) _prefill(user);
    final canSave = user != null && !_saving;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onBack: () => context.pop(),
              saving: _saving,
              onSave: canSave ? () => _save(user) : null,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _uploadingPhoto ? null : () => _pickAvatar(user),
                      child: Column(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              color: AppColors.tanFixed,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: _uploadingPhoto
                                ? const CircularProgressIndicator(
                                    color: AppColors.espresso)
                                : (user?.avatarUrl != null
                                    ? Image.network(
                                        user!.avatarUrl!,
                                        width: 96,
                                        height: 96,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => const Icon(
                                            Icons.checkroom,
                                            color: AppColors.espresso,
                                            size: 48),
                                      )
                                    : const Icon(Icons.checkroom,
                                        color: AppColors.espresso, size: 48)),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Change Photo',
                            style:
                                Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: AppColors.espresso,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _FieldLabel('Name'),
                  DrapeTextField(label: 'Name', controller: _name),
                  const SizedBox(height: 16),
                  _FieldLabel('Email'),
                  DrapeTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    suffix: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sageDim,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check,
                                color: AppColors.sage, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              'VERIFIED',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.sageContent,
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('Phone Number (Optional)'),
                  DrapeTextField(
                    label: 'Phone',
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Gender'),
                            _Dropdown(
                              value: _gender,
                              options: _genderOptions,
                              onChanged: (v) => setState(() => _gender = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _FieldLabel('Age Range'),
                            _Dropdown(
                              value: _ageRange,
                              options: _ageOptions,
                              onChanged: (v) => setState(() => _ageRange = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _FieldLabel('Location'),
                  DrapeTextField(
                    label: 'Location',
                    controller: _location,
                    suffix: const Icon(Icons.location_on_outlined,
                        color: AppColors.taupe),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Used for timezone and local shopping',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.ivoryWarm,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Styling Preferences',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(
                          'Your profile data helps our AI stylist curate outfits tailored to your unique demographic and aesthetic profile.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            _PrefChip('MINIMALIST'),
                            _PrefChip('HIGH-CONTRAST'),
                            _PrefChip('EARTH TONES'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  DrapeButton(
                    label: _saving ? 'Saving…' : 'Save Changes',
                    onPressed: canSave ? () => _save(user) : null,
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
  final VoidCallback? onSave;
  final bool saving;
  const _Header({required this.onBack, required this.onSave, this.saving = false});

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
              'Edit Profile',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          saving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.espresso),
                  ),
                )
              : TextButton(
                  onPressed: onSave,
                  child: Text(
                    'Save',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.espresso,
                          fontWeight: FontWeight.w700,
                        ),
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
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.inkSoft,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _Dropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.taupeSoft),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.taupe, size: 18),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.ink,
              ),
          items: options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _PrefChip extends StatelessWidget {
  final String label;
  const _PrefChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tanFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.espressoDark,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
