import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/models/vehicle.dart';
import 'package:admin_app/screens/hire_detail_screen.dart';
import 'package:admin_app/screens/vehicle_detail_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

AdminUser _user({bool update = true, bool delete = true}) => AdminUser(
      id: 1,
      name: 'ZZZ Test Admin',
      email: 'zzz@example.test',
      canCreateHires: true,
      canUpdateHires: update,
      canDeleteHires: delete,
    );

/// A van with a fully filled-in hire (#11) and one of each other tour type.
FakeServer _server() => FakeServer(
      vehicles: [
        vehicleJson(
          id: 1,
          model: 'ZZZ Test Van',
          stats: vehicleStatsJson(hireCount: 2, full: 55000, our: 44000, all: 5, today: 2, scheduled: 3),
        ),
      ],
      hires: {
        1: [
          hireJson(
            id: 11,
            vehicleId: 1,
            tab: 'today',
            customer: 'ZZZ Test Customer',
            driver: 'ZZZ Test Driver',
            from: 'ZZZ Old From',
            to: 'ZZZ Old To',
            startTime: '2026-09-29T18:09:00+00:00',
            full: 30000,
            our: 24000,
            description: 'ZZZ before',
          ),
          hireJson(
            id: 12,
            vehicleId: 1,
            tab: 'scheduled',
            tourType: 'day_tour',
            from: 'ZZZ Day From',
            to: 'ZZZ Day To',
            stayLocations: ['ZZZ Stay A', 'ZZZ Stay B'],
            startTime: '2026-10-05T08:00:00+00:00',
          ),
          hireJson(
            id: 13,
            vehicleId: 1,
            tab: 'scheduled',
            tourType: 'multi_day',
            from: null,
            to: null,
            dayLocations: [
              ['ZZZ Day1 A', 'ZZZ Day1 B'],
              ['ZZZ Day2 A'],
            ],
            startTime: '2026-10-06T08:00:00+00:00',
          ),
          hireJson(
            id: 14,
            vehicleId: 1,
            tab: 'scheduled',
            tourType: 'package',
            from: null,
            to: null,
            packageId: 1,
            startTime: '2026-10-07T08:00:00+00:00',
            endTime: '2026-10-09T18:00:00+00:00',
          ),
          hireJson(
            id: 15,
            vehicleId: 1,
            tab: 'today',
            status: 'started',
            customer: 'ZZZ Running Customer',
            startTime: '2026-09-25T08:00:00+00:00',
          ),
          hireJson(
            id: 16,
            vehicleId: 1,
            tab: 'completed',
            status: 'completed',
            customer: 'ZZZ Old Customer',
            startTime: '2020-01-15T09:00:00+00:00',
          ),
        ],
      },
    );

Future<void> _openHire(WidgetTester tester, FakeServer server, int id, {AdminUser? user}) async {
  tester.view.physicalSize = const Size(412, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(
    theme: buildAdminAppTheme(),
    home: Navigator(
      onGenerateRoute: (_) => MaterialPageRoute(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HireDetailScreen(hireId: id, user: user ?? _user())),
              ),
              child: const Text('open hire'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open hire'));
  await tester.pumpAndSettle();
}

Future<void> _openForm(WidgetTester tester, FakeServer server, int id, {AdminUser? user}) async {
  await _openHire(tester, server, id, user: user);
  await tester.tap(find.byKey(const Key('edit-hire')));
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, String label) => tester
    .widget<TextField>(find.descendant(of: find.widgetWithText(TextFormField, label), matching: find.byType(TextField)))
    .controller!
    .text;

Future<void> _save(WidgetTester tester) async {
  final save = find.widgetWithText(ElevatedButton, 'Save Changes');
  await tester.ensureVisible(save);
  await tester.tap(save);
  await tester.pumpAndSettle();
}

void main() {
  group('the Edit and Delete buttons', () {
    testWidgets('are both on the hire page for someone who may edit and delete', (tester) async {
      await _openHire(tester, _server(), 11);

      expect(find.byKey(const Key('edit-hire')), findsOneWidget);
      expect(find.byKey(const Key('delete-hire')), findsOneWidget);
    });

    testWidgets('only Edit for someone who may edit but not delete', (tester) async {
      await _openHire(tester, _server(), 11, user: _user(delete: false));

      expect(find.byKey(const Key('edit-hire')), findsOneWidget);
      expect(find.byKey(const Key('delete-hire')), findsNothing);
    });

    testWidgets('only Delete for someone who may delete but not edit', (tester) async {
      await _openHire(tester, _server(), 11, user: _user(update: false));

      expect(find.byKey(const Key('edit-hire')), findsNothing);
      expect(find.byKey(const Key('delete-hire')), findsOneWidget);
    });

    testWidgets('neither for someone who may do neither', (tester) async {
      await _openHire(tester, _server(), 11, user: _user(update: false, delete: false));

      expect(find.byKey(const Key('edit-hire')), findsNothing);
      expect(find.byKey(const Key('delete-hire')), findsNothing);
      expect(find.text('Hire #11'), findsOneWidget);
    });

    testWidgets('are not offered when the hire failed to load', (tester) async {
      final server = _server()..failWith = 500;
      await _openHire(tester, server, 11);

      expect(find.byKey(const Key('edit-hire')), findsNothing);
      expect(find.byKey(const Key('delete-hire')), findsNothing);
    });
  });

  group('editing a hire', () {
    testWidgets('opens the form as Edit Hire, filled in with what the hire has', (tester) async {
      await _openForm(tester, _server(), 11);

      expect(find.text('Edit Hire'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save Changes'), findsOneWidget);
      expect(find.text('Create Hire'), findsNothing);
      expect(find.text('ZZZ Test Customer · 0770000000'), findsOneWidget); // the customer, selected
      expect(find.text('ZZZ Test Driver'), findsOneWidget);
      expect(find.text('ZZZ Test Van'), findsOneWidget); // vehicle dropdown, not locked
      expect(find.byKey(const Key('locked-vehicle')), findsNothing);
      expect(_text(tester, 'From location'), 'ZZZ Old From');
      expect(_text(tester, 'To location'), 'ZZZ Old To');
      expect(_text(tester, 'Hire full value (Rs.)'), '30000');
      expect(_text(tester, 'Our hire value (Rs.)'), '24000');
      expect(_text(tester, 'Description'), 'ZZZ before');
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Sep 29, 2026 · 6:09 PM'), findsOneWidget); // the same clock time the hire has
    });

    testWidgets('saves what was changed, and the hire page shows it', (tester) async {
      final server = _server();
      await _openForm(tester, server, 11);

      await tester.enterText(find.widgetWithText(TextFormField, 'Hire full value (Rs.)'), '31000');
      await tester.enterText(find.widgetWithText(TextFormField, 'To location'), 'ZZZ New Destination');
      await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'ZZZ after');
      await tester.pump(const Duration(milliseconds: 500));
      await _save(tester);

      expect(server.updatedHires, hasLength(1));
      final sent = server.updatedHires.single;
      expect(sent.id, 11);
      expect(sent.body['tour_type'], 'drop_pickup');
      expect(sent.body['customer_id'], 1);
      expect(sent.body['driver_id'], 1);
      expect(sent.body['vehicle_id'], 1);
      expect(sent.body['from_location_name'], 'ZZZ Old From');
      expect(sent.body['to_location_name'], 'ZZZ New Destination');
      expect(sent.body['hire_full_value'], '31000');
      expect(sent.body['our_hire_value'], '24000');
      expect(sent.body['description'], 'ZZZ after');

      // Back on the hire page, showing the saved hire.
      expect(find.text('Edit Hire'), findsNothing);
      expect(find.text('Hire #11'), findsOneWidget);
      expect(find.text('Hire #11 updated.'), findsOneWidget);
      expect(find.text('Rs. 31,000.00'), findsOneWidget);
      expect(find.text('ZZZ after'), findsOneWidget);
    });

    testWidgets('does not create a second hire', (tester) async {
      final server = _server();
      await _openForm(tester, server, 11);

      await _save(tester);

      expect(server.createdHires, isEmpty);
      expect(server.updatedHires, hasLength(1));
    });

    testWidgets('saving without changes sends the same clock time — it does not drift', (tester) async {
      final server = _server();
      await _openForm(tester, server, 11);

      await _save(tester);

      // Entered as 6:09 PM; saved as 6:09 PM again, with no zone shift.
      expect(server.updatedHires.single.body['start_time'], startsWith('2026-09-29T18:09:00'));
    });

    testWidgets('a hire in the past can still open its date picker', (tester) async {
      final server = _server();
      await _openForm(tester, server, 16);

      await tester.ensureVisible(find.text('Scheduled date & time'));
      await tester.tap(find.text('Scheduled date & time'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(find.textContaining('January 2020'), findsWidgets);
    });

    testWidgets('a day tour comes with its stays', (tester) async {
      await _openForm(tester, _server(), 12);

      expect(_text(tester, 'From location'), 'ZZZ Day From');
      expect(_text(tester, 'Stay location 1'), 'ZZZ Stay A');
      expect(_text(tester, 'Stay location 2'), 'ZZZ Stay B');
    });

    testWidgets('a multi-day tour comes with its days', (tester) async {
      await _openForm(tester, _server(), 13);

      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Day 2'), findsOneWidget);
      final all = tester.widgetList<TextField>(find.byType(TextField)).map((f) => f.controller?.text);
      expect(all, containsAll(['ZZZ Day1 A', 'ZZZ Day1 B', 'ZZZ Day2 A']));
    });

    testWidgets('a package hire comes with its package and dates', (tester) async {
      await _openForm(tester, _server(), 14);

      expect(find.text('ZZZ Test Package'), findsOneWidget);
      expect(find.text('Oct 7, 2026 · 8:00 AM'), findsOneWidget);
      expect(find.text('Oct 9, 2026 · 6:00 PM'), findsOneWidget);
    });

    testWidgets('a driver or customer that is no longer on offer does not break the form', (tester) async {
      final server = _server();
      server.hires[1]![0] = hireJson(id: 11, vehicleId: 1, customerId: 999, customer: 'ZZZ Gone Customer', driverId: 999, driver: 'ZZZ Gone Driver', startTime: '2026-09-29T18:09:00+00:00');
      await _openForm(tester, server, 11);

      expect(tester.takeException(), isNull);
      expect(find.text('Edit Hire'), findsOneWidget);
      expect(find.text('ZZZ Gone Customer'), findsNothing);
    });

    testWidgets('will not save an emptied field, and says so', (tester) async {
      final server = _server();
      await _openForm(tester, server, 11);

      await tester.enterText(find.widgetWithText(TextFormField, 'Hire full value (Rs.)'), '');
      await _save(tester);

      expect(server.updatedHires, isEmpty);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Edit Hire'), findsOneWidget);
    });

    testWidgets('shows the server\'s reason and stays on the form when it refuses', (tester) async {
      final server = _server();
      await _openForm(tester, server, 11);
      server.failMethods['PUT'] = 422;

      await _save(tester);

      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.text('Edit Hire'), findsOneWidget);
      expect(find.text('Hire #11 updated.'), findsNothing);
    });

    testWidgets('backing out of the form saves nothing', (tester) async {
      final server = _server();
      await _openForm(tester, server, 11);

      await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'ZZZ never saved');
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(server.updatedHires, isEmpty);
      expect(find.text('ZZZ never saved'), findsNothing);
      expect(find.text('ZZZ before'), findsOneWidget);
    });
  });

  group('deleting a hire', () {
    testWidgets('asks first, saying what will be lost', (tester) async {
      final server = _server();
      await _openHire(tester, server, 11);

      await tester.tap(find.byKey(const Key('delete-hire')));
      await tester.pumpAndSettle();

      expect(find.text('Delete hire #11?'), findsOneWidget);
      expect(find.textContaining('ZZZ Test Customer will be deleted for good'), findsOneWidget);
      expect(find.textContaining('payments, expenses and tracking history'), findsOneWidget);
      expect(find.textContaining('tracking will stop'), findsNothing); // not running
      expect(server.deletedHires, isEmpty);
    });

    testWidgets('"Keep hire" changes nothing', (tester) async {
      final server = _server();
      await _openHire(tester, server, 11);
      await tester.tap(find.byKey(const Key('delete-hire')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('keep-hire')));
      await tester.pumpAndSettle();

      expect(find.text('Delete hire #11?'), findsNothing);
      expect(find.text('Hire #11'), findsOneWidget);
      expect(server.deletedHires, isEmpty);
    });

    testWidgets('warns extra when the hire is running', (tester) async {
      await _openHire(tester, _server(), 15);
      await tester.tap(find.byKey(const Key('delete-hire')));
      await tester.pumpAndSettle();

      expect(find.textContaining('This hire is running right now'), findsOneWidget);
    });

    testWidgets('deletes it, says so, and leaves the hire page', (tester) async {
      final server = _server();
      await _openHire(tester, server, 11);
      await tester.tap(find.byKey(const Key('delete-hire')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-delete-hire')));
      await tester.pumpAndSettle();

      expect(server.deletedHires, [11]);
      expect(find.text('Hire #11'), findsNothing); // the hire page is closed
      expect(find.text('open hire'), findsOneWidget); // back where it was opened from
      expect(find.text('Hire #11 deleted.'), findsOneWidget);
    });

    testWidgets('keeps the hire and shows why when the server refuses', (tester) async {
      final server = _server();
      await _openHire(tester, server, 11);
      server.failMethods['DELETE'] = 403;
      await tester.tap(find.byKey(const Key('delete-hire')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('confirm-delete-hire')));
      await tester.pumpAndSettle();

      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.text('Hire #11'), findsOneWidget); // still on the hire
      expect(find.byKey(const Key('delete-hire')), findsOneWidget); // and can try again
      expect(find.text('Hire #11 deleted.'), findsNothing);
    });
  });

  group('from the vehicle\'s page', () {
    Future<void> openVehicle(WidgetTester tester, FakeServer server) async {
      tester.view.physicalSize = const Size(412, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await server.install();
      await tester.pumpWidget(MaterialApp(
        theme: buildAdminAppTheme(),
        home: VehicleDetailScreen(vehicle: Vehicle.fromJson(server.vehicles.first), user: _user()),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('a deleted hire leaves the list and the counts', (tester) async {
      final server = _server();
      await openVehicle(tester, server);
      expect(find.text('ZZZ Running Customer'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tab-all')), matching: find.text('5')), findsOneWidget);

      await tester.tap(find.text('ZZZ Running Customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-hire')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-hire')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Running Customer'), findsNothing);
      expect(find.descendant(of: find.byKey(const Key('tab-all')), matching: find.text('4')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('tab-today')), matching: find.text('1')), findsOneWidget);
    });

    testWidgets('an edited hire shows its new details in the list', (tester) async {
      final server = _server();
      await openVehicle(tester, server);
      expect(find.text('ZZZ Old From → ZZZ Old To'), findsOneWidget);

      await tester.tap(find.text('ZZZ Old From → ZZZ Old To'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('edit-hire')));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'To location'), 'ZZZ Edited Place');
      await tester.pump(const Duration(milliseconds: 500));
      await _save(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Old From → ZZZ Edited Place'), findsOneWidget);
      expect(find.text('ZZZ Old From → ZZZ Old To'), findsNothing);
    });
  });
}
