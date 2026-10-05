import 'package:admin_app/screens/drivers_tab.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/fake_server.dart';

final _now = DateTime.now();
final _thisMonth = DateTime(_now.year, _now.month);
final _lastMonth = DateTime(_now.year, _now.month - 1);
final _thisMonthLabel = DateFormat('MMMM y').format(_thisMonth);
final _lastMonthLabel = DateFormat('MMMM y').format(_lastMonth);

Future<void> _show(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: DriversTab(user: server.adminUser)));
  await tester.pumpAndSettle();
}

FakeServer _roster() => FakeServer(drivers: [
      driverJson(id: 1, name: 'ZZZ Test Zebra', contactNumber: '0771111111'),
      driverJson(id: 2, name: 'ZZZ Test Apple', contactNumber: '0772222222', email: 'zzz.apple@example.test'),
    ]);

void main() {
  testWidgets('lists drivers with name and contact number', (tester) async {
    await _show(tester, _roster());

    expect(find.text('ZZZ Test Zebra'), findsOneWidget);
    expect(find.text('0771111111'), findsOneWidget);
    expect(find.text('ZZZ Test Apple'), findsOneWidget);
  });

  testWidgets('searches the roster', (tester) async {
    final server = _roster();
    await _show(tester, server);

    await tester.enterText(find.byKey(const Key('driver-search')), 'Apple');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(server.requestsTo('/api/admin/drivers').last.url.queryParameters['search'], 'Apple');
    expect(find.text('ZZZ Test Apple'), findsOneWidget);
    expect(find.text('ZZZ Test Zebra'), findsNothing);
  });

  testWidgets('offers Add Driver to someone allowed to add one', (tester) async {
    await _show(tester, _roster()..canCreateDrivers = true);

    expect(find.byKey(const Key('add-driver')), findsOneWidget);
  });

  testWidgets('hides Add Driver from someone who may not add drivers', (tester) async {
    await _show(tester, _roster()..canCreateDrivers = false);

    expect(find.byKey(const Key('add-driver')), findsNothing);
  });

  testWidgets('invites you to add the first driver when there are none', (tester) async {
    await _show(tester, FakeServer());

    expect(find.text('No drivers yet'), findsOneWidget);
  });

  group('adding a driver', () {
    Future<void> openForm(WidgetTester tester, FakeServer server) async {
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-driver')));
      await tester.pumpAndSettle();
    }

    testWidgets('creates one and returns to the roster', (tester) async {
      final server = _roster();
      await openForm(tester, server);

      await tester.enterText(find.byKey(const Key('driver-name')), 'ZZZ New Driver');
      await tester.enterText(find.byKey(const Key('driver-license')), 'ZZZ-LIC-9');
      await tester.enterText(find.byKey(const Key('driver-contact')), '0779999999');
      await tester.enterText(find.byKey(const Key('driver-email')), 'zzz.new@example.test');
      await tester.enterText(find.byKey(const Key('driver-password')), 'password123');
      await tester.ensureVisible(find.byKey(const Key('save-driver')));
      await tester.tap(find.byKey(const Key('save-driver')));
      await tester.pumpAndSettle();

      expect(server.createdDrivers.single['name'], 'ZZZ New Driver');
      expect(find.byKey(const Key('driver-name')), findsNothing); // back on the roster
      expect(find.text('ZZZ New Driver added.'), findsOneWidget);
      expect(find.text('ZZZ New Driver'), findsOneWidget);
    });

    testWidgets('will not submit an empty form', (tester) async {
      final server = _roster();
      await openForm(tester, server);

      await tester.ensureVisible(find.byKey(const Key('save-driver')));
      await tester.tap(find.byKey(const Key('save-driver')));
      await tester.pumpAndSettle();

      expect(server.createdDrivers, isEmpty);
      expect(find.text('Required'), findsWidgets);
    });

    testWidgets('shows the server\'s validation message', (tester) async {
      final server = _roster();
      await openForm(tester, server);

      await tester.enterText(find.byKey(const Key('driver-name')), 'ZZZ New Driver');
      await tester.enterText(find.byKey(const Key('driver-license')), 'ZZZ-LIC-9');
      await tester.enterText(find.byKey(const Key('driver-contact')), '0779999999');
      await tester.enterText(find.byKey(const Key('driver-email')), 'zzz.new@example.test');
      await tester.enterText(find.byKey(const Key('driver-password')), 'password123');
      server.failWith = 422;
      await tester.ensureVisible(find.byKey(const Key('save-driver')));
      await tester.tap(find.byKey(const Key('save-driver')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('driver-form-error')), findsOneWidget);
      expect(find.text('The server said no.'), findsOneWidget);
    });
  });

  group('a driver\'s page', () {
    Future<void> openDriver(WidgetTester tester, FakeServer server, {bool canUpdateDrivers = false, bool canDeleteDrivers = false}) async {
      server
        ..canUpdateDrivers = canUpdateDrivers
        ..canDeleteDrivers = canDeleteDrivers;
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('driver-card-1')));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the driver\'s details', (tester) async {
      await openDriver(tester, _roster());

      expect(find.text('ZZZ Test Zebra'), findsWidgets); // title + tile
      expect(find.text('0771111111'), findsOneWidget);
    });

    testWidgets('offers no menu to someone who may neither edit nor delete', (tester) async {
      await openDriver(tester, _roster());

      expect(find.byKey(const Key('driver-menu')), findsNothing);
    });

    testWidgets('editing saves changes', (tester) async {
      await openDriver(tester, _roster(), canUpdateDrivers: true);

      await tester.tap(find.byKey(const Key('driver-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('driver-name')), 'ZZZ Renamed Driver');
      await tester.ensureVisible(find.byKey(const Key('save-driver')));
      await tester.tap(find.byKey(const Key('save-driver')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Renamed Driver'), findsWidgets);
      expect(find.text('ZZZ Renamed Driver updated.'), findsOneWidget);
    });

    testWidgets('deleting asks for confirmation, then pops the page', (tester) async {
      final server = _roster();
      await openDriver(tester, server, canDeleteDrivers: true);

      await tester.tap(find.byKey(const Key('driver-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-delete-driver')));
      await tester.pumpAndSettle();

      expect(server.deletedDrivers, [1]);
      expect(find.text('ZZZ Test Zebra'), findsNothing); // popped, and gone from the roster
    });
  });

  group('the Hires tab', () {
    Future<void> openHiresTab(WidgetTester tester, FakeServer server) async {
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('driver-card-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-hires')));
      await tester.pumpAndSettle();
    }

    /// Driver 1 has two hires this month and one last month; driver 2's hire
    /// this month belongs to someone else and must never show up.
    FakeServer withHires() => _roster()
      ..allHires.addAll([
        hireJson(id: 101, driverId: 1, driver: 'ZZZ Test Zebra', full: 5000, our: 4000, startTime: dayOf(_thisMonth, 3)),
        hireJson(id: 102, driverId: 1, driver: 'ZZZ Test Zebra', full: 3000, our: 2000, startTime: dayOf(_thisMonth, 15)),
        hireJson(id: 103, driverId: 1, driver: 'ZZZ Test Zebra', full: 7000, our: 5000, startTime: dayOf(_lastMonth, 20)),
        hireJson(id: 104, driverId: 2, driver: 'ZZZ Test Apple', full: 9999, our: 9999, startTime: dayOf(_thisMonth, 10)),
      ]);

    testWidgets('shows this month\'s hires for the driver, with the total', (tester) async {
      final server = withHires();
      await openHiresTab(tester, server);

      expect(find.text(_thisMonthLabel), findsOneWidget);
      expect(find.text('Rs. 5,000'), findsOneWidget); // hire 101
      expect(find.text('Rs. 3,000'), findsOneWidget); // hire 102
      expect(find.text('Rs. 7,000'), findsNothing); // hire 103, last month
      expect(find.text('Rs. 9,999'), findsNothing); // hire 104, someone else's

      final queries = server.requestsTo('/api/admin/hires').map((r) => r.url.queryParameters);
      expect(queries.last['driver_id'], '1');
      // 5,000 + 3,000 full, 4,000 + 2,000 our.
      expect(find.text('2 hires · Rs. 8,000 total · Rs. 6,000 our value · Rs. 2,000 commission'), findsOneWidget);
    });

    testWidgets('stepping to the previous month shows that month instead', (tester) async {
      final server = withHires();
      await openHiresTab(tester, server);

      await tester.tap(find.byKey(const Key('hire-history-month-prev')));
      await tester.pumpAndSettle();

      expect(find.text(_lastMonthLabel), findsOneWidget);
      expect(find.text('Rs. 7,000'), findsOneWidget); // hire 103
      expect(find.text('Rs. 5,000'), findsNothing); // hire 101, this month
      expect(find.text('1 hire · Rs. 7,000 total · Rs. 5,000 our value · Rs. 2,000 commission'), findsOneWidget);
    });

    testWidgets('an empty month says so', (tester) async {
      await openHiresTab(tester, _roster());

      expect(find.text('No hires this month'), findsOneWidget);
      expect(find.text('Nothing recorded for $_thisMonthLabel.'), findsOneWidget);
      expect(find.text('0 hires · Rs. 0 total · Rs. 0 our value · Rs. 0 commission'), findsOneWidget);
    });

    testWidgets('tapping a hire opens its details', (tester) async {
      await openHiresTab(tester, withHires());

      await tester.tap(find.text('Rs. 5,000')); // hire 101
      await tester.pumpAndSettle();

      expect(find.text('Hire #101'), findsOneWidget);
    });
  });
}
