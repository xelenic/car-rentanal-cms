import 'dart:convert';

import 'package:admin_app/services/theme_store.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryThemeStore implements ThemeStore {
  String? saved;

  _MemoryThemeStore([this.saved]);

  @override
  Future<String?> read() async => saved;

  @override
  Future<void> write(String variant) async => saved = variant;
}

void main() {
  test('defaults to Indigo — today\'s app, unchanged', () async {
    final controller = ThemeController.test(_MemoryThemeStore());
    expect(controller.variant, AppThemeVariant.indigo);

    // AppColors backs onto shared static state another test may have left
    // on a different variant — force a real apply (not the short-circuited
    // no-op setVariant takes when already on the target) so this check does
    // not depend on running before any other test in the suite.
    await controller.setVariant(AppThemeVariant.dark);
    await controller.setVariant(AppThemeVariant.indigo);

    expect(AppColors.background, const Color(0xFFF7F8FB));
  });

  test('setVariant updates AppColors, notifies listeners, and persists', () async {
    final store = _MemoryThemeStore();
    final controller = ThemeController.test(store);
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setVariant(AppThemeVariant.dark);

    expect(controller.variant, AppThemeVariant.dark);
    expect(AppColors.background, const Color(0xFF0B1220));
    expect(AppColors.brightness, Brightness.dark);
    expect(notified, 1);
    expect(jsonDecode(store.saved!), {'variant': 'dark'});
  });

  test('setVariant with the already-active variant is a no-op', () async {
    final controller = ThemeController.test(_MemoryThemeStore());
    var notified = 0;
    controller.addListener(() => notified++);

    await controller.setVariant(AppThemeVariant.indigo);

    expect(notified, 0);
  });

  test('load() restores a previously saved variant', () async {
    final controller = ThemeController.test(_MemoryThemeStore('emerald'));

    await controller.load();

    expect(controller.variant, AppThemeVariant.emerald);
    expect(AppColors.primary, const Color(0xFF059669));
  });

  test('load() with nothing saved keeps the default', () async {
    final controller = ThemeController.test(_MemoryThemeStore());

    await controller.load();

    expect(controller.variant, AppThemeVariant.indigo);
  });

  test('load() with an unrecognized saved value keeps the default', () async {
    final controller = ThemeController.test(_MemoryThemeStore('not-a-real-theme'));

    await controller.load();

    expect(controller.variant, AppThemeVariant.indigo);
  });

  group('Custom theme', () {
    test('switching to Custom the first time starts from whatever was active', () async {
      final controller = ThemeController.test(_MemoryThemeStore());
      await controller.setVariant(AppThemeVariant.emerald);

      await controller.setVariant(AppThemeVariant.custom);

      expect(controller.customPalette.primary, const Color(0xFF059669)); // Emerald's accent
    });

    test('updateCustomPalette changes one color, switches to Custom, and persists both', () async {
      final store = _MemoryThemeStore();
      final controller = ThemeController.test(store);

      await controller.updateCustomPalette((p) => p.copyWith(primary: const Color(0xFF123456)));

      expect(controller.variant, AppThemeVariant.custom);
      expect(controller.customPalette.primary, const Color(0xFF123456));
      expect(AppColors.primary, const Color(0xFF123456));

      final saved = jsonDecode(store.saved!) as Map<String, dynamic>;
      expect(saved['variant'], 'custom');
      expect(saved['colors']['primary'], 'ff123456');
    });

    test('returning to Custom after a different preset keeps earlier custom picks', () async {
      final controller = ThemeController.test(_MemoryThemeStore());
      await controller.updateCustomPalette((p) => p.copyWith(primary: const Color(0xFF123456)));

      await controller.setVariant(AppThemeVariant.dark);
      await controller.setVariant(AppThemeVariant.custom);

      expect(controller.customPalette.primary, const Color(0xFF123456));
    });

    test('resetCustomPalette clears back to Indigo', () async {
      final controller = ThemeController.test(_MemoryThemeStore());
      await controller.updateCustomPalette((p) => p.copyWith(primary: const Color(0xFF123456)));

      await controller.resetCustomPalette();

      expect(controller.customPalette.primary, const Color(0xFF4F46E5));
      expect(AppColors.primary, const Color(0xFF4F46E5)); // still on Custom, so it's live
    });

    test('load() restores a saved custom palette', () async {
      final saved = jsonEncode({
        'variant': 'custom',
        'colors': {'background': 'ff112233', 'primary': 'ffaabbcc'},
      });
      final controller = ThemeController.test(_MemoryThemeStore(saved));

      await controller.load();

      expect(controller.variant, AppThemeVariant.custom);
      expect(controller.customPalette.background, const Color(0xFF112233));
      expect(controller.customPalette.primary, const Color(0xFFAABBCC));
      // Fields absent from the save fall back to Indigo's.
      expect(controller.customPalette.textPrimary, const Color(0xFF1E293B));
    });
  });
}
