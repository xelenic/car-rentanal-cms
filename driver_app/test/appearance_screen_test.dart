import 'dart:convert';

import 'package:driver_app/screens/appearance_screen.dart';
import 'package:driver_app/services/theme_store.dart';
import 'package:driver_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
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
  testWidgets('shows all five themes, with the active one checked', (tester) async {
    final controller = ThemeController.test(_MemoryThemeStore());
    await controller.setVariant(AppThemeVariant.dark);

    await tester.pumpWidget(_app(AppearanceScreen(controller: controller)));

    expect(find.text('Sky Blue'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Orange'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.byIcon(Icons.circle_outlined), findsNWidgets(4));
  });

  testWidgets('only Custom shows an edit button', (tester) async {
    final controller = ThemeController.test(_MemoryThemeStore());

    await tester.pumpWidget(_app(AppearanceScreen(controller: controller)));

    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
  });

  testWidgets('tapping a theme selects it and persists the choice', (tester) async {
    final store = _MemoryThemeStore();
    final controller = ThemeController.test(store);

    await tester.pumpWidget(_app(AppearanceScreen(controller: controller)));
    expect(controller.variant, AppThemeVariant.skyBlue);

    await tester.tap(find.text('Orange'));
    await tester.pumpAndSettle();

    expect(controller.variant, AppThemeVariant.orange);
    expect(jsonDecode(store.saved!), {'variant': 'orange'});
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('tapping Custom activates it without opening the editor', (tester) async {
    final controller = ThemeController.test(_MemoryThemeStore());

    await tester.pumpWidget(_app(AppearanceScreen(controller: controller)));
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();

    expect(controller.variant, AppThemeVariant.custom);
    expect(find.byType(AppearanceScreen), findsOneWidget); // still here, didn't navigate
  });

  testWidgets('the edit button opens the custom color editor', (tester) async {
    final controller = ThemeController.test(_MemoryThemeStore());

    await tester.pumpWidget(_app(AppearanceScreen(controller: controller)));
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Custom Theme'), findsOneWidget);
  });

  testWidgets('falls back to ThemeController.instance when none is passed', (tester) async {
    await tester.pumpWidget(_app(const AppearanceScreen()));

    expect(find.text('Sky Blue'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });
}
