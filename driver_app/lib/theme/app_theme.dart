import 'package:flutter/material.dart';

/// Light, sky-blue accented palette for the driver app.
class AppColors {
  AppColors._();

  static const background = Color(0xFFF4FAFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceElevated = Color(0xFFEAF6FF);
  static const border = Color(0xFFDCEEFB);

  static const neon = Color(0xFF0EA5E9);
  static const neonDeep = Color(0xFF0284C7);
  static const onNeon = Color(0xFFFFFFFF);

  static const textPrimary = Color(0xFF0F2A43);
  static const textSecondary = Color(0xFF5B7A93);
  static const textMuted = Color(0xFF94AEC2);

  static const danger = Color(0xFFE11D48);
  static const warning = Color(0xFFD97706);
  static const info = Color(0xFF0D9488);
}

ThemeData buildDriverAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.light(
      primary: AppColors.neon,
      onPrimary: AppColors.onNeon,
      secondary: AppColors.neonDeep,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.neon, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neon,
        foregroundColor: AppColors.onNeon,
        disabledBackgroundColor: AppColors.neon.withValues(alpha: 0.35),
        padding: const EdgeInsets.symmetric(vertical: 15),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.neon.withValues(alpha: 0.14),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.neonDeep : AppColors.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.neonDeep : AppColors.textSecondary,
        );
      }),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.neonDeep,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.neon,
      dividerColor: AppColors.border,
      labelStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    iconTheme: const IconThemeData(color: AppColors.textPrimary),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
