import 'package:driver_app/screens/custom_theme_screen.dart';
import 'package:driver_app/services/theme_store.dart';
import 'package:driver_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryThemeStore implements ThemeStore {
  String? saved;

  @override
  Future<String?> read() async => saved;

  @override
  Future<void> write(String variant) async => saved = variant;
}

Widget _app(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('renders every group and field, with Sky Blue colors by default', (tester) async {
    // All 4 groups and 14 fields at once — taller than the default test
    // surface, so nothing is left off-screen (and thus unbuilt) to find.
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = ThemeController.test(_MemoryThemeStore());

    await tester.pumpWidget(_app(CustomThemeScreen(controller: controller)));

    expect(find.text('Background & Surfaces'), findsOneWidget);
    expect(find.text('Accent'), findsWidgets); // the group title and the Accent field share the word
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Status Colors'), findsOneWidget);

    expect(find.text('Background'), findsOneWidget);
    expect(find.text('#F4FAFF'), findsOneWidget); // Sky Blue's background
    expect(find.text('#0EA5E9'), findsOneWidget); // Sky Blue's accent
  });

  testWidgets('tapping a row opens the color picker for that field', (tester) async {
    final controller = ThemeController.test(_MemoryThemeStore());

    await tester.pumpWidget(_app(CustomThemeScreen(controller: controller)));
    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();

    expect(find.byType(ColorPicker), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('entering a hex and tapping Select updates the palette and switches to Custom', (tester) async {
    final controller = ThemeController.test(_MemoryThemeStore());

    await tester.pumpWidget(_app(CustomThemeScreen(controller: controller)));
    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '#123456');
    await tester.pump();
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();

    expect(controller.variant, AppThemeVariant.custom);
    expect(controller.customPalette.background, const Color(0xFF123456));
    expect(find.text('#123456'), findsOneWidget);
  });

  testWidgets('Cancel leaves the palette unchanged', (tester) async {
    final controller = ThemeController.test(_MemoryThemeStore());

    await tester.pumpWidget(_app(CustomThemeScreen(controller: controller)));
    await tester.tap(find.text('Background'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '#123456');
    await tester.pump();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(controller.variant, AppThemeVariant.skyBlue);
    expect(find.text('#F4FAFF'), findsOneWidget);
  });

  testWidgets('the reset button asks first, then clears back to Sky Blue', (tester) async {
    final controller = ThemeController.test(_MemoryThemeStore());
    await controller.updateCustomPalette((p) => p.copyWith(background: const Color(0xFF123456)));

    await tester.pumpWidget(_app(CustomThemeScreen(controller: controller)));
    expect(find.text('#123456'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pumpAndSettle();
    expect(find.text('Reset custom colors?'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(controller.customPalette.background, const Color(0xFFF4FAFF));
    expect(find.text('#F4FAFF'), findsOneWidget);
  });
}
