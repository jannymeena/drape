import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DrapeTextField extends StatefulWidget {
  final String label;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final String? errorText;

  const DrapeTextField({
    super.key,
    required this.label,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.suffix,
    this.onChanged,
    this.textInputAction,
    this.focusNode,
    this.errorText,
  });

  @override
  State<DrapeTextField> createState() => _DrapeTextFieldState();
}

class _DrapeTextFieldState extends State<DrapeTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final defaultSuffix = widget.obscureText
        ? IconButton(
            icon: Icon(
              _obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.taupe,
              size: 20,
            ),
            onPressed: () => setState(() => _obscured = !_obscured),
          )
        : null;

    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      validator: widget.validator,
      onChanged: widget.onChanged,
      textInputAction: widget.textInputAction,
      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.ink),
      decoration: InputDecoration(
        labelText: widget.label,
        labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
            ),
        floatingLabelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.espresso,
            ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        errorText: widget.errorText,
        suffixIcon: widget.suffix ?? defaultSuffix,
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
          borderSide: const BorderSide(color: AppColors.espresso, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}
