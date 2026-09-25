import 'package:admin_app/screens/vehicles_dashboard_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

Future<FakeServer> _openForm(WidgetTester tester, {FakeServer? server}) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final fake = server ?? FakeServer(vehicles: [vehicleJson(id: 1, model: 'ZZZ Test Van')]);
  await fake.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: const VehiclesDashboardScreen()));
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('add-vehicle')));
  await tester.pumpAndSettle();
  return fake;
}

Future<void> _fill(WidgetTester tester, {String model = 'ZZZ Test Bus', String seats = '30', String pax = '28'}) async {
  await tester.enterText(find.byKey(const Key('vehicle-model')), model);
  await tester.enterText(find.byKey(const Key('vehicle-seats')), seats);
  await tester.enterText(find.byKey(const Key('vehicle-pax')), pax);
}

Future<void> _save(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('save-vehicle')));
  await tester.tap(find.byKey(const Key('save-vehicle')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens the form from the dashboard', (tester) async {
    await _openForm(tester);

    expect(find.text('Add Vehicle'), findsWidgets);
    expect(find.byKey(const Key('vehicle-model')), findsOneWidget);
    expect(find.byKey(const Key('vehicle-condition')), findsOneWidget);
    expect(find.byKey(const Key('vehicle-seats')), findsOneWidget);
    expect(find.byKey(const Key('vehicle-pax')), findsOneWidget);
  });

  testWidgets('saves the vehicle, returns to the dashboard and shows the new card', (tester) async {
    final server = await _openForm(tester);

    await _fill(tester);
    await tester.enterText(find.byKey(const Key('vehicle-description')), 'ZZZ roomy');
    await tester.tap(find.byKey(const Key('vehicle-condition')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excellent').last);
    await tester.pumpAndSettle();
    await _save(tester);

    expect(server.createdVehicles, [
      {'model': 'ZZZ Test Bus', 'condition': 'Excellent', 'seats': 30, 'pax': 28, 'description': 'ZZZ roomy'},
    ]);
    expect(find.byKey(const Key('vehicle-model')), findsNothing); // back on the dashboard
    expect(find.text('ZZZ Test Bus added.'), findsOneWidget);
    expect(find.text('ZZZ Test Bus'), findsOneWidget); // the new card
    expect(find.text('30 seats · 28 passengers'), findsOneWidget);
  });

  testWidgets('sends no description when it is left blank', (tester) async {
    final server = await _openForm(tester);

    await _fill(tester);
    await _save(tester);

    expect(server.createdVehicles.single['description'], isNull);
    expect(server.createdVehicles.single['condition'], 'Good'); // the default
  });

  testWidgets('will not submit an empty form and says what is missing', (tester) async {
    final server = await _openForm(tester);

    await _save(tester);

    expect(server.createdVehicles, isEmpty);
    expect(find.text('Required'), findsNWidgets(3)); // model, seats, passengers
  });

  testWidgets('rejects seat counts outside 1 to 100', (tester) async {
    final server = await _openForm(tester);

    await _fill(tester, seats: '0', pax: '101');
    await _save(tester);

    expect(server.createdVehicles, isEmpty);
    expect(find.text('Enter 1 to 100'), findsNWidgets(2));
  });

  testWidgets('only accepts digits for seats and passengers', (tester) async {
    await _openForm(tester);

    await tester.enterText(find.byKey(const Key('vehicle-seats')), '1a2.5');

    expect(tester.widget<TextField>(find.descendant(of: find.byKey(const Key('vehicle-seats')), matching: find.byType(TextField))).controller!.text, '125');
  });

  testWidgets('shows the server\'s reason and stays on the form when it refuses', (tester) async {
    final server = await _openForm(tester);
    server.failWith = 422;

    await _fill(tester);
    await _save(tester);

    expect(find.byKey(const Key('add-vehicle-error')), findsOneWidget);
    expect(find.text('The server said no.'), findsOneWidget);
    expect(find.byKey(const Key('vehicle-model')), findsOneWidget);
    expect(server.createdVehicles, isEmpty);
    expect(find.byType(SnackBar), findsNothing);
  });
}
