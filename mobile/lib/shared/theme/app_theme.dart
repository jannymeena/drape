import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  AppTheme._();

  static const _colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.espresso,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.espressoDark,
    onPrimaryContainer: AppColors.tan,
    secondary: AppColors.sage,
    onSecondary: AppColors.white,
    secondaryContainer: AppColors.sageDim,
    onSecondaryContainer: AppColors.sageContent,
    tertiary: AppColors.goldDark,
    onTertiary: AppColors.white,
    tertiaryContainer: AppColors.gold,
    onTertiaryContainer: AppColors.goldDark,
    error: AppColors.error,
    onError: AppColors.white,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.ivory,
    onSurface: AppColors.ink,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: AppColors.ivoryDim,
    surfaceContainer: AppColors.ivoryWarm,
    surfaceContainerHigh: AppColors.sand,
    surfaceContainerHighest: AppColors.sand,
    onSurfaceVariant: AppColors.inkSoft,
    outline: AppColors.taupe,
    outlineVariant: AppColors.taupeSoft,
    shadow: AppColors.black,
    scrim: AppColors.black,
    inverseSurface: Color(0xFF31302D),
    onInverseSurface: Color(0xFFF4F0EB),
    inversePrimary: Color(0xFFF0BBA0),
  );

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _colorScheme,
        scaffoldBackgroundColor: AppColors.ivory,
        textTheme: AppTypography.textTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.ivory,
          foregroundColor: AppColors.ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.taupeSoft,
          thickness: 1,
          space: 1,
        ),
        splashFactory: InkRipple.splashFactory,
      );
}
