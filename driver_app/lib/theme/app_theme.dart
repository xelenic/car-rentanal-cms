import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/theme_store.dart';

/// One theme's full set of colors. Immutable — switching themes swaps which
/// instance [AppColors] reads from, rather than mutating one in place.
class AppPalette {
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color border;

  final Color neon;
  final Color neonDeep;
  final Color onNeon;

  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  final Color danger;
  final Color warning;
  final Color info;
  final Color success;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.border,
    required this.neon,
    required this.neonDeep,
    required this.onNeon,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.danger,
    required this.warning,
    required this.info,
    required this.success,
  });

  /// Derived from [background] rather than stored — a custom palette's
  /// background can change color without anything having to keep this in
  /// sync by hand.
  Brightness get brightness => ThemeData.estimateBrightnessForColor(background);

  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? surfaceElevated,
    Color? border,
    Color? neon,
    Color? neonDeep,
    Color? onNeon,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? danger,
    Color? warning,
    Color? info,
    Color? success,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceElevated: surfaceElevated ?? this.surfaceElevated,
      border: border ?? this.border,
      neon: neon ?? this.neon,
      neonDeep: neonDeep ?? this.neonDeep,
      onNeon: onNeon ?? this.onNeon,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      info: info ?? this.info,
      success: success ?? this.success,
    );
  }

  Map<String, String> toJson() => {
        'background': _hex(background),
        'surface': _hex(surface),
        'surfaceElevated': _hex(surfaceElevated),
        'border': _hex(border),
        'neon': _hex(neon),
        'neonDeep': _hex(neonDeep),
        'onNeon': _hex(onNeon),
        'textPrimary': _hex(textPrimary),
        'textSecondary': _hex(textSecondary),
        'textMuted': _hex(textMuted),
        'danger': _hex(danger),
        'warning': _hex(warning),
        'info': _hex(info),
        'success': _hex(success),
      };

  /// Builds from [toJson]'s shape. Any missing or unparsable entry — an
  /// older save, a storage hiccup — falls back to [fallback]'s color rather
  /// than failing outright.
  factory AppPalette.fromJson(Map<String, dynamic> json, {required AppPalette fallback}) {
    Color read(String key, Color fallbackColor) {
      final raw = json[key];
      return raw is String ? (_unhex(raw) ?? fallbackColor) : fallbackColor;
    }

    return AppPalette(
      background: read('background', fallback.background),
      surface: read('surface', fallback.surface),
      surfaceElevated: read('surfaceElevated', fallback.surfaceElevated),
      border: read('border', fallback.border),
      neon: read('neon', fallback.neon),
      neonDeep: read('neonDeep', fallback.neonDeep),
      onNeon: read('onNeon', fallback.onNeon),
      textPrimary: read('textPrimary', fallback.textPrimary),
      textSecondary: read('textSecondary', fallback.textSecondary),
      textMuted: read('textMuted', fallback.textMuted),
      danger: read('danger', fallback.danger),
      warning: read('warning', fallback.warning),
      info: read('info', fallback.info),
      success: read('success', fallback.success),
    );
  }
}

String _hex(Color c) => c.toARGB32().toRadixString(16).padLeft(8, '0');

Color? _unhex(String s) {
  final parsed = int.tryParse(s, radix: 16);
  return parsed != null ? Color(parsed) : null;
}

/// One editable row on the Custom Theme screen: a named color plus how to
/// read and replace it on an [AppPalette]. Top-level functions (not
/// closures) so the whole list below can be `const`.
class PaletteField {
  final String key;
  final String label;
  final Color Function(AppPalette) read;
  final AppPalette Function(AppPalette, Color) write;

  const PaletteField({required this.key, required this.label, required this.read, required this.write});
}

class PaletteGroup {
  final String title;
  final List<PaletteField> fields;

  const PaletteGroup(this.title, this.fields);
}

Color _readBackground(AppPalette p) => p.background;
AppPalette _writeBackground(AppPalette p, Color c) => p.copyWith(background: c);
Color _readSurface(AppPalette p) => p.surface;
AppPalette _writeSurface(AppPalette p, Color c) => p.copyWith(surface: c);
Color _readSurfaceElevated(AppPalette p) => p.surfaceElevated;
AppPalette _writeSurfaceElevated(AppPalette p, Color c) => p.copyWith(surfaceElevated: c);
Color _readBorder(AppPalette p) => p.border;
AppPalette _writeBorder(AppPalette p, Color c) => p.copyWith(border: c);

Color _readNeon(AppPalette p) => p.neon;
AppPalette _writeNeon(AppPalette p, Color c) => p.copyWith(neon: c);
Color _readNeonDeep(AppPalette p) => p.neonDeep;
AppPalette _writeNeonDeep(AppPalette p, Color c) => p.copyWith(neonDeep: c);
Color _readOnNeon(AppPalette p) => p.onNeon;
AppPalette _writeOnNeon(AppPalette p, Color c) => p.copyWith(onNeon: c);

Color _readTextPrimary(AppPalette p) => p.textPrimary;
AppPalette _writeTextPrimary(AppPalette p, Color c) => p.copyWith(textPrimary: c);
Color _readTextSecondary(AppPalette p) => p.textSecondary;
AppPalette _writeTextSecondary(AppPalette p, Color c) => p.copyWith(textSecondary: c);
Color _readTextMuted(AppPalette p) => p.textMuted;
AppPalette _writeTextMuted(AppPalette p, Color c) => p.copyWith(textMuted: c);

Color _readDanger(AppPalette p) => p.danger;
AppPalette _writeDanger(AppPalette p, Color c) => p.copyWith(danger: c);
Color _readWarning(AppPalette p) => p.warning;
AppPalette _writeWarning(AppPalette p, Color c) => p.copyWith(warning: c);
Color _readInfo(AppPalette p) => p.info;
AppPalette _writeInfo(AppPalette p, Color c) => p.copyWith(info: c);
Color _readSuccess(AppPalette p) => p.success;
AppPalette _writeSuccess(AppPalette p, Color c) => p.copyWith(success: c);

/// Every color a custom theme can set, grouped the same way as the rest of
/// this file's comments group [AppPalette]'s fields.
const paletteGroups = <PaletteGroup>[
  PaletteGroup('Background & Surfaces', [
    PaletteField(key: 'background', label: 'Background', read: _readBackground, write: _writeBackground),
    PaletteField(key: 'surface', label: 'Surface', read: _readSurface, write: _writeSurface),
    PaletteField(key: 'surfaceElevated', label: 'Elevated Surface', read: _readSurfaceElevated, write: _writeSurfaceElevated),
    PaletteField(key: 'border', label: 'Border', read: _readBorder, write: _writeBorder),
  ]),
  PaletteGroup('Accent', [
    PaletteField(key: 'neon', label: 'Accent', read: _readNeon, write: _writeNeon),
    PaletteField(key: 'neonDeep', label: 'Accent (Deep)', read: _readNeonDeep, write: _writeNeonDeep),
    PaletteField(key: 'onNeon', label: 'Text on Accent', read: _readOnNeon, write: _writeOnNeon),
  ]),
  PaletteGroup('Text', [
    PaletteField(key: 'textPrimary', label: 'Primary Text', read: _readTextPrimary, write: _writeTextPrimary),
    PaletteField(key: 'textSecondary', label: 'Secondary Text', read: _readTextSecondary, write: _writeTextSecondary),
    PaletteField(key: 'textMuted', label: 'Muted Text', read: _readTextMuted, write: _writeTextMuted),
  ]),
  PaletteGroup('Status Colors', [
    PaletteField(key: 'danger', label: 'Danger', read: _readDanger, write: _writeDanger),
    PaletteField(key: 'warning', label: 'Warning', read: _readWarning, write: _writeWarning),
    PaletteField(key: 'info', label: 'Info', read: _readInfo, write: _writeInfo),
    PaletteField(key: 'success', label: 'Success', read: _readSuccess, write: _writeSuccess),
  ]),
];

/// Today's app, unchanged — kept as one selectable theme rather than always
/// being "the" theme.
const _skyBluePalette = AppPalette(
  background: Color(0xFFF4FAFF),
  surface: Color(0xFFFFFFFF),
  surfaceElevated: Color(0xFFEAF6FF),
  border: Color(0xFFDCEEFB),
  neon: Color(0xFF0EA5E9),
  neonDeep: Color(0xFF0284C7),
  onNeon: Color(0xFFFFFFFF),
  textPrimary: Color(0xFF0F2A43),
  textSecondary: Color(0xFF5B7A93),
  textMuted: Color(0xFF94AEC2),
  danger: Color(0xFFE11D48),
  warning: Color(0xFFD97706),
  info: Color(0xFF0D9488),
  success: Color(0xFF16A34A),
);

/// Neutral, white-backed light theme — same blue accent as Sky Blue, no blue
/// tint on the background or surfaces.
const _lightPalette = AppPalette(
  background: Color(0xFFFFFFFF),
  surface: Color(0xFFFFFFFF),
  surfaceElevated: Color(0xFFF2F4F7),
  border: Color(0xFFE3E7ED),
  neon: Color(0xFF0EA5E9),
  neonDeep: Color(0xFF0284C7),
  onNeon: Color(0xFFFFFFFF),
  textPrimary: Color(0xFF111827),
  textSecondary: Color(0xFF4B5563),
  textMuted: Color(0xFF9CA3AF),
  danger: Color(0xFFE11D48),
  warning: Color(0xFFD97706),
  info: Color(0xFF0D9488),
  success: Color(0xFF16A34A),
);

const _darkPalette = AppPalette(
  background: Color(0xFF0B1220),
  surface: Color(0xFF121A2B),
  surfaceElevated: Color(0xFF1A2338),
  border: Color(0xFF26304A),
  neon: Color(0xFF38BDF8),
  neonDeep: Color(0xFF0EA5E9),
  onNeon: Color(0xFF04131C),
  textPrimary: Color(0xFFF1F5F9),
  textSecondary: Color(0xFF94A3B8),
  textMuted: Color(0xFF64748B),
  danger: Color(0xFFFB7185),
  warning: Color(0xFFFBBF24),
  info: Color(0xFF2DD4BF),
  success: Color(0xFF4ADE80),
);

/// Warm, orange-accented theme — same structure as Sky Blue/Light, recolored.
const _orangePalette = AppPalette(
  background: Color(0xFFFFF7ED),
  surface: Color(0xFFFFFFFF),
  surfaceElevated: Color(0xFFFFEDD5),
  border: Color(0xFFFED7AA),
  neon: Color(0xFFF97316),
  neonDeep: Color(0xFFC2410C),
  onNeon: Color(0xFFFFFFFF),
  textPrimary: Color(0xFF2B1A0E),
  textSecondary: Color(0xFF78716C),
  textMuted: Color(0xFFC2A68D),
  danger: Color(0xFFE11D48),
  warning: Color(0xFFD97706),
  info: Color(0xFF0D9488),
  success: Color(0xFF16A34A),
);

/// The themes a driver can pick on Appearance — four fixed ones plus Custom,
/// whose colors come from [ThemeController.customPalette] instead of a
/// preset (so [presetPalette] is null for it).
enum AppThemeVariant {
  skyBlue('Sky Blue', _skyBluePalette),
  light('Light', _lightPalette),
  dark('Dark', _darkPalette),
  orange('Orange', _orangePalette),
  custom('Custom', null);

  final String label;
  final AppPalette? presetPalette;

  const AppThemeVariant(this.label, this.presetPalette);
}

/// The driver app's palette, read from everywhere a color is needed.
///
/// Every member reads from the currently active theme's [AppPalette] — call
/// sites don't change when the theme does, only which values these getters
/// return.
class AppColors {
  AppColors._();

  static AppPalette _current = _skyBluePalette;

  static Color get background => _current.background;
  static Color get surface => _current.surface;
  static Color get surfaceElevated => _current.surfaceElevated;
  static Color get border => _current.border;

  static Color get neon => _current.neon;
  static Color get neonDeep => _current.neonDeep;
  static Color get onNeon => _current.onNeon;

  static Color get textPrimary => _current.textPrimary;
  static Color get textSecondary => _current.textSecondary;
  static Color get textMuted => _current.textMuted;

  static Color get danger => _current.danger;
  static Color get warning => _current.warning;
  static Color get info => _current.info;
  static Color get success => _current.success;

  static Brightness get brightness => _current.brightness;
}

/// Picks the driver's theme, persists it, and tells the app to rebuild.
class ThemeController extends ChangeNotifier {
  static final ThemeController instance = ThemeController._(const SecureThemeStore());

  final ThemeStore _store;
  AppThemeVariant _variant = AppThemeVariant.skyBlue;

  /// The driver's own colors, once they've set any — null means "never
  /// customized yet", not "empty", so switching to Custom for the first
  /// time can tell that apart from returning to colors already picked.
  AppPalette? _customPalette;

  ThemeController._(this._store);

  /// Only for tests — a real app only ever uses [instance].
  ThemeController.test(this._store);

  AppThemeVariant get variant => _variant;
  AppPalette get customPalette => _customPalette ?? _skyBluePalette;

  AppPalette get _activePalette => _variant == AppThemeVariant.custom ? customPalette : _variant.presetPalette!;

  /// Restores the saved theme, if any. Call once at startup.
  Future<void> load() async {
    final saved = await _store.read();
    if (saved == null) return;

    final decoded = _tryDecodeJson(saved);
    // A bare variant name from before Custom existed is still a valid save.
    final variantName = decoded != null ? decoded['variant'] as String? : saved;
    final match = AppThemeVariant.values.where((v) => v.name == variantName);
    if (match.isEmpty) return;

    final colors = decoded?['colors'];
    if (colors is Map<String, dynamic>) {
      _customPalette = AppPalette.fromJson(colors, fallback: _skyBluePalette);
    }
    _apply(match.first);
  }

  Future<void> setVariant(AppThemeVariant variant) async {
    if (variant == _variant) return;
    if (variant == AppThemeVariant.custom && _customPalette == null) {
      // First time entering Custom: start from whatever was active, not an
      // unrelated default. Guarded on _customPalette being null so a later
      // visit — after it's actually been customized — keeps those colors
      // instead of re-copying whatever preset was active just before.
      _customPalette = _activePalette;
    }
    _apply(variant);
    await _persist();
  }

  /// Replaces every custom color with Sky Blue's — the safety valve for a
  /// driver who has picked a combination that's gone unreadable.
  Future<void> resetCustomPalette() async {
    _customPalette = null;
    if (_variant == AppThemeVariant.custom) AppColors._current = customPalette;
    notifyListeners();
    await _persist();
  }

  /// Changes one color of the custom theme (see [paletteGroups]), switching
  /// to Custom first if it wasn't already active. Builds on whatever custom
  /// colors already exist — picking Dark in between and coming back to
  /// Custom later never loses earlier picks.
  Future<void> updateCustomPalette(AppPalette Function(AppPalette current) update) async {
    _customPalette = update(customPalette);
    _variant = AppThemeVariant.custom;
    AppColors._current = _customPalette!;
    notifyListeners();
    await _persist();
  }

  void _apply(AppThemeVariant variant) {
    _variant = variant;
    AppColors._current = _activePalette;
    notifyListeners();
  }

  Future<void> _persist() async {
    final payload = _variant == AppThemeVariant.custom
        ? {'variant': _variant.name, 'colors': customPalette.toJson()}
        : {'variant': _variant.name};
    await _store.write(jsonEncode(payload));
  }

  Map<String, dynamic>? _tryDecodeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}

ThemeData buildDriverAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: AppColors.brightness,
  );

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme(
      brightness: AppColors.brightness,
      primary: AppColors.neon,
      onPrimary: AppColors.onNeon,
      secondary: AppColors.neonDeep,
      onSecondary: AppColors.onNeon,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      error: AppColors.danger,
      onError: AppColors.onNeon,
    ),
    appBarTheme: AppBarTheme(
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
        side: BorderSide(color: AppColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.neon, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.danger),
      ),
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 14),
      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
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
    tabBarTheme: TabBarThemeData(
      labelColor: AppColors.neonDeep,
      unselectedLabelColor: AppColors.textSecondary,
      indicatorColor: AppColors.neon,
      dividerColor: AppColors.border,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
    ),
    dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    iconTheme: IconThemeData(color: AppColors.textPrimary),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
  );
}
