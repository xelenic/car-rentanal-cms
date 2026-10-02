import 'package:admin_app/screens/home_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

Future<void> _show(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: const HomeScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows all six shortcuts to a fully-permissioned user', (tester) async {
    await _show(tester, FakeServer());

    for (final key in [
      'shortcut-overview',
      'shortcut-hires',
      'shortcut-vehicles',
      'shortcut-drivers',
      'shortcut-customers',
      'shortcut-expenses',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.text('Car Rental CMS'), findsOneWidget); // the AppBar title
  });

  testWidgets('hides a shortcut the user may not view', (tester) async {
    final server = FakeServer()
      ..canViewDrivers = false
      ..canViewCustomers = false;
    await _show(tester, server);

    expect(find.byKey(const Key('shortcut-vehicles')), findsOneWidget);
    // Overview is gated on canViewDrivers too, same as the web dashboard.
    expect(find.byKey(const Key('shortcut-overview')), findsNothing);
    expect(find.byKey(const Key('shortcut-drivers')), findsNothing);
    expect(find.byKey(const Key('shortcut-customers')), findsNothing);
    expect(find.byKey(const Key('shortcut-expenses')), findsOneWidget);
  });

  testWidgets('Hires is always offered, even with every other permission off', (tester) async {
    final server = FakeServer()
      ..canViewVehicles = false
      ..canViewDrivers = false
      ..canViewCustomers = false
      ..canViewMyExpenses = false;
    await _show(tester, server);

    expect(find.byKey(const Key('shortcut-hires')), findsOneWidget);
  });

  testWidgets('tapping Vehicles pushes a standalone Vehicles page', (tester) async {
    await _show(tester, FakeServer(vehicles: [vehicleJson(id: 1, model: 'ZZZ Test Van')]));

    await tester.tap(find.byKey(const Key('shortcut-vehicles')));
    await tester.pumpAndSettle();

    expect(find.text('Vehicles'), findsWidgets); // this page's own AppBar title
    expect(find.byKey(const Key('vehicle-card-1')), findsOneWidget);

    // It's a standalone page — Back returns to the shortcut grid, not a tab bar.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shortcut-vehicles')), findsOneWidget);
  });

  testWidgets('tapping Drivers pushes a standalone Drivers page', (tester) async {
    await _show(tester, FakeServer(drivers: [driverJson(id: 1, name: 'ZZZ Test Driver')]));

    await tester.tap(find.byKey(const Key('shortcut-drivers')));
    await tester.pumpAndSettle();

    expect(find.text('Drivers'), findsWidgets);
    expect(find.text('ZZZ Test Driver'), findsOneWidget);
    expect(find.byKey(const Key('shortcut-vehicles')), findsNothing); // the grid is gone, not just covered
  });

  testWidgets('tapping Expenses pushes a standalone Expenses page', (tester) async {
    await _show(tester, FakeServer());

    await tester.tap(find.byKey(const Key('shortcut-expenses')));
    await tester.pumpAndSettle();

    expect(find.text('Expenses'), findsWidgets);
    expect(find.byKey(const Key('card-my-profit')), findsOneWidget);
  });

  testWidgets('tapping Overview pushes the dashboard page', (tester) async {
    await _show(tester, FakeServer());

    await tester.tap(find.byKey(const Key('shortcut-overview')));
    await tester.pumpAndSettle();

    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Total Hire Value'), findsOneWidget);
  });

  testWidgets('tapping Hires pushes the hires list page', (tester) async {
    await _show(tester, FakeServer(allHires: [hireJson(id: 1, customer: 'ZZZ Test Customer')]));

    await tester.tap(find.byKey(const Key('shortcut-hires')));
    await tester.pumpAndSettle();

    expect(find.text('Hires'), findsWidgets);
    expect(find.text('ZZZ Test Customer'), findsOneWidget);
  });

  testWidgets('logs out and returns to the login screen', (tester) async {
    await _show(tester, FakeServer());

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('logout')), findsNothing);
    expect(find.text('Admin Panel'), findsOneWidget); // the login screen
  });

  testWidgets('a user with every other permission off still sees just Hires, not an empty shell', (tester) async {
    final server = FakeServer()
      ..canViewVehicles = false
      ..canViewDrivers = false
      ..canViewCustomers = false
      ..canViewMyExpenses = false;
    await _show(tester, server);

    // Hires is still always offered (hires.view is required just to sign
    // in), so a real "no access at all" state is unreachable through
    // permissions alone — the grid always has at least this one shortcut.
    expect(find.byKey(const Key('shortcut-hires')), findsOneWidget);
    expect(find.byKey(const Key('shortcut-overview')), findsNothing);
    expect(find.byKey(const Key('shortcut-vehicles')), findsNothing);
    expect(find.byKey(const Key('logout')), findsOneWidget); // still a way out
  });

  testWidgets('tells someone the sign-in failed, rather than showing an empty shell', (tester) async {
    final server = FakeServer()..failWith = 500;
    await _show(tester, server);

    expect(find.textContaining('Could not sign you in'), findsOneWidget);
    expect(find.byKey(const Key('logout')), findsOneWidget); // still a way out
  });
}
