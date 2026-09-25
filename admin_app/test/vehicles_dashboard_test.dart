import 'package:admin_app/screens/vehicles_dashboard_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

Future<void> _show(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: const VehiclesDashboardScreen()));
  await tester.pumpAndSettle();
}

FakeServer _fleet() => FakeServer(vehicles: [
      vehicleJson(
        id: 1,
        model: 'ZZZ Test Van',
        condition: 'Excellent',
        seats: 9,
        pax: 8,
        stats: vehicleStatsJson(
          hireCount: 6,
          full: 120000,
          our: 80000,
          monthCount: 2,
          monthFull: 30000,
          all: 8,
          today: 2,
          scheduled: 1,
          completed: 4,
          cancelled: 1,
          running: 1,
        ),
      ),
      vehicleJson(id: 2, model: 'ZZZ Test Car', condition: 'Poor', seats: 1, pax: 1),
    ]);

void main() {
  testWidgets('shows the fleet as cards with each vehicle\'s numbers', (tester) async {
    await _show(tester, _fleet());

    expect(find.text('Vehicles'), findsWidgets); // title + the summary's tile
    expect(find.text('ZZZ Test Van'), findsOneWidget);
    expect(find.text('ZZZ Test Car'), findsOneWidget);
    expect(find.text('9 seats · 8 passengers'), findsOneWidget);
    expect(find.text('1 seat · 1 passenger'), findsOneWidget);
    expect(find.text('Excellent'), findsOneWidget);
    expect(find.text('Poor'), findsOneWidget);

    final van = find.byKey(const Key('vehicle-card-1'));
    expect(find.descendant(of: van, matching: find.text('Rs. 120,000')), findsOneWidget);
    expect(find.descendant(of: van, matching: find.text('Rs. 40,000')), findsOneWidget); // commission
    expect(find.descendant(of: van, matching: find.text('This month · 2 hires · Rs. 30,000')), findsOneWidget);
    expect(find.descendant(of: van, matching: find.text('6')), findsOneWidget); // hires
    expect(find.descendant(of: van, matching: find.text('1 running now')), findsOneWidget);
    expect(find.descendant(of: van, matching: find.text('Today 2')), findsOneWidget);
    expect(find.descendant(of: van, matching: find.text('Scheduled 1')), findsOneWidget);
    expect(find.descendant(of: van, matching: find.text('Completed 4')), findsOneWidget);
    expect(find.descendant(of: van, matching: find.text('Cancelled 1')), findsOneWidget);

    final car = find.byKey(const Key('vehicle-card-2'));
    expect(find.descendant(of: car, matching: find.text('Today 0')), findsOneWidget);
    expect(find.descendant(of: car, matching: find.text('1 running now')), findsNothing);
  });

  testWidgets('leads with the whole-fleet totals', (tester) async {
    await _show(tester, _fleet());

    final summary = find.byKey(const Key('fleet-summary'));
    expect(find.descendant(of: summary, matching: find.text('2')), findsOneWidget); // vehicles
    expect(find.descendant(of: summary, matching: find.text('7')), findsOneWidget); // hires
    expect(find.descendant(of: summary, matching: find.text('Rs. 1.25M')), findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('Rs. 250,000')), findsOneWidget);
  });

  testWidgets('does not list any hires — only vehicles', (tester) async {
    final server = _fleet();
    await _show(tester, server);

    expect(server.paths, isNot(contains('/api/admin/hires')));
    expect(server.paths.where((p) => p.contains('/hires')), isEmpty);
    expect(find.byKey(const Key('vehicle-card-1')), findsOneWidget);
  });

  testWidgets('offers Add Vehicle to someone allowed to add one', (tester) async {
    await _show(tester, _fleet()..canCreateVehicles = true);

    expect(find.byKey(const Key('add-vehicle')), findsOneWidget);
  });

  testWidgets('hides Add Vehicle from someone who may not add vehicles', (tester) async {
    await _show(tester, _fleet()..canCreateVehicles = false);

    expect(find.byKey(const Key('add-vehicle')), findsNothing);
  });

  testWidgets('searches the fleet as you type', (tester) async {
    final server = _fleet();
    await _show(tester, server);

    await tester.enterText(find.byKey(const Key('vehicle-search')), 'car');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(server.requestsTo('/api/admin/vehicles').last.url.queryParameters['search'], 'car');
    expect(find.text('ZZZ Test Car'), findsOneWidget);
    expect(find.text('ZZZ Test Van'), findsNothing);
    // The fleet totals are for the whole fleet, so they step aside while filtering.
    expect(find.byKey(const Key('fleet-summary')), findsNothing);
  });

  testWidgets('says so when a search matches nothing', (tester) async {
    await _show(tester, _fleet());

    await tester.enterText(find.byKey(const Key('vehicle-search')), 'zebra');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('No vehicles match'), findsOneWidget);
  });

  testWidgets('invites you to add the first vehicle when there are none', (tester) async {
    await _show(tester, FakeServer());

    expect(find.text('No vehicles yet'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Add Vehicle'), findsOneWidget);
  });

  testWidgets('shows the server\'s message and retries', (tester) async {
    final server = _fleet()..failWith = 500;
    await _show(tester, server);

    expect(find.text('The server said no.'), findsOneWidget);

    server.failWith = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('ZZZ Test Van'), findsOneWidget);
  });

  testWidgets('pages the fleet: the next page loads when you reach the end', (tester) async {
    final server = FakeServer(
      pageSize: 5,
      vehicles: [for (var i = 1; i <= 8; i++) vehicleJson(id: i, model: 'ZZZ Test Vehicle $i')],
    );
    await _show(tester, server);

    expect(server.requestsTo('/api/admin/vehicles').map((r) => r.url.queryParameters['page']), ['1']);
    expect(find.text('ZZZ Test Vehicle 8', skipOffstage: false), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();

    expect(server.requestsTo('/api/admin/vehicles').map((r) => r.url.queryParameters['page']), ['1', '2']);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(find.text('ZZZ Test Vehicle 8'), findsOneWidget);
  });

  testWidgets('a vehicle card opens that vehicle\'s page', (tester) async {
    await _show(tester, _fleet());

    await tester.tap(find.byKey(const Key('vehicle-card-2')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('vehicle-header')), findsOneWidget);
    expect(find.text('ZZZ Test Car'), findsOneWidget); // app bar
  });
}
