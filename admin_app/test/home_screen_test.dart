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
  testWidgets('shows all four tabs to a fully-permissioned user, starting on Vehicles', (tester) async {
    await _show(tester, FakeServer(vehicles: [vehicleJson(id: 1, model: 'ZZZ Test Van')]));

    for (final key in ['home-tab-vehicles', 'home-tab-drivers', 'home-tab-customers', 'home-tab-expenses']) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    expect(find.text('Vehicles'), findsWidgets); // the AppBar title
    expect(find.byKey(const Key('vehicle-card-1')), findsOneWidget);
  });

  testWidgets('hides a tab the user may not view', (tester) async {
    final server = FakeServer(vehicles: [vehicleJson(id: 1)])
      ..canViewDrivers = false
      ..canViewCustomers = false;
    await _show(tester, server);

    expect(find.byKey(const Key('home-tab-vehicles')), findsOneWidget);
    expect(find.byKey(const Key('home-tab-drivers')), findsNothing);
    expect(find.byKey(const Key('home-tab-customers')), findsNothing);
    expect(find.byKey(const Key('home-tab-expenses')), findsOneWidget);
  });

  testWidgets('switching tabs changes the title and loads that tab\'s data', (tester) async {
    final server = FakeServer(
      vehicles: [vehicleJson(id: 1)],
      drivers: [driverJson(id: 1, name: 'ZZZ Test Driver')],
    );
    await _show(tester, server);

    await tester.ensureVisible(find.byKey(const Key('home-tab-drivers')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tab-drivers')));
    await tester.pumpAndSettle();

    expect(find.text('Drivers'), findsWidgets); // the AppBar title
    expect(find.text('ZZZ Test Driver'), findsOneWidget);
    expect(server.requestsTo('/api/admin/drivers'), isNotEmpty);
  });

  testWidgets('the Expenses tab shows My Expenses content, embedded (no second app bar)', (tester) async {
    await _show(tester, FakeServer(vehicles: [vehicleJson(id: 1)]));

    await tester.ensureVisible(find.byKey(const Key('home-tab-expenses')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-tab-expenses')));
    await tester.pumpAndSettle();

    expect(find.text('Expenses'), findsWidgets); // the shared AppBar title, not a second "My Expenses" bar
    expect(find.byKey(const Key('card-my-profit')), findsOneWidget);
  });

  testWidgets('logs out and returns to the login screen', (tester) async {
    await _show(tester, FakeServer(vehicles: [vehicleJson(id: 1)]));

    await tester.tap(find.byKey(const Key('logout')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('logout')), findsNothing);
    expect(find.text('Admin Panel'), findsOneWidget); // the login screen
  });

  testWidgets('tells someone with no access at all, rather than showing an empty shell', (tester) async {
    final server = FakeServer()
      ..canViewVehicles = false
      ..canViewDrivers = false
      ..canViewCustomers = false
      ..canViewMyExpenses = false;
    await _show(tester, server);

    expect(find.text('You do not have access to any section yet. Ask an admin to grant you a permission.'), findsOneWidget);
    expect(find.byKey(const Key('logout')), findsOneWidget); // still a way out
  });
}
