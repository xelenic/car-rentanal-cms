import 'package:driver_app/screens/options_screen.dart';
import 'package:driver_app/screens/vehicle_maintenance_entry_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A few bounded pumps rather than pumpAndSettle — the destination screens
/// fetch from the real network on init, which never resolves in a test
/// environment, so settling would hang forever.
Future<void> _pumpSome(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  testWidgets('the grid offers Revenue License, alongside Vehicle Repair', (tester) async {
    // Tall enough that every tile in the (scrollable, lazily-built) grid is
    // on screen, Revenue License included.
    tester.view.physicalSize = const Size(800, 2700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
    await _pumpSome(tester);

    expect(find.text('Revenue License'), findsOneWidget);
    expect(find.text('Vehicle Repair'), findsOneWidget);
  });

  testWidgets('tapping Revenue License opens its own entry screen, not the Vehicle Repair hub', (tester) async {
    tester.view.physicalSize = const Size(800, 2700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: OptionsScreen()));
    await _pumpSome(tester);

    await tester.tap(find.text('Revenue License'));
    await _pumpSome(tester);

    expect(find.widgetWithText(AppBar, 'Revenue License'), findsOneWidget);
    final screen = tester.widget<VehicleMaintenanceEntryScreen>(find.byType(VehicleMaintenanceEntryScreen));
    expect(screen.type, 'revenue_license');
  });
}
