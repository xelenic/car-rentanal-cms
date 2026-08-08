import 'package:flutter/material.dart';

/// Dark, neon-green accented palette for the driver app.
class AppColors {
  AppColors._();

  static const background = Color(0xFF0C0E12);
  static const surface = Color(0xFF16191F);
  static const surfaceElevated = Color(0xFF1E222A);
  static const border = Color(0xFF272C35);

  static const neon = Color(0xFF3DFF9A);
  static const neonDeep = Color(0xFF00C853);
  static const onNeon = Color(0xFF06210F);

  static const textPrimary = Color(0xFFF3F5F7);
  static const textSecondary = Color(0xFF9AA1AC);
  static const textMuted = Color(0xFF676E79);

  static const danger = Color(0xFFFF6B7A);
  static const warning = Color(0xFFFFC259);
  static const info = Color(0xFF5EC8FF);
}

ThemeData buildDriverAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
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
      indicatorColor: AppColors.neon.withValues(alpha: 0.16),
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AppColors.neon : AppColors.textSecondary,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? AppColors.neon : AppColors.textSecondary,
        );
      }),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.neon,
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
