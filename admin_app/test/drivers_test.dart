import 'package:admin_app/screens/drivers_tab.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

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
}
