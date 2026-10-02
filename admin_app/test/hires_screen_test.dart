import 'package:admin_app/screens/hire_detail_screen.dart';
import 'package:admin_app/screens/hire_form_screen.dart';
import 'package:admin_app/screens/hires_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

Future<void> _show(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(
    MaterialApp(theme: buildAdminAppTheme(), home: HiresScreen(user: server.adminUser)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every hire via HireCard', (tester) async {
    await _show(
      tester,
      FakeServer(allHires: [
        hireJson(id: 1, customer: 'ZZZ First Customer'),
        hireJson(id: 2, customer: 'ZZZ Second Customer'),
      ]),
    );

    expect(find.text('ZZZ First Customer'), findsOneWidget);
    expect(find.text('ZZZ Second Customer'), findsOneWidget);
  });

  testWidgets('shows an empty state with no hires yet', (tester) async {
    await _show(tester, FakeServer());

    expect(find.text('No hires yet'), findsOneWidget);
  });

  testWidgets('search narrows the list and asks the server for it', (tester) async {
    final server = FakeServer(allHires: [hireJson(id: 1, customer: 'ZZZ Searchable')]);
    await _show(tester, server);

    await tester.enterText(find.byKey(const Key('hire-search')), 'ZZZ Searchable');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final requests = server.requestsTo('/api/admin/hires');
    expect(requests.last.url.queryParameters['search'], 'ZZZ Searchable');
  });

  testWidgets('the Upcoming filter chip asks the server for upcoming only', (tester) async {
    final server = FakeServer(allHires: [hireJson(id: 1)]);
    await _show(tester, server);

    await tester.tap(find.byKey(const Key('upcoming-only')));
    await tester.pumpAndSettle();

    final requests = server.requestsTo('/api/admin/hires');
    expect(requests.last.url.queryParameters['upcoming'], '1');
  });

  testWidgets('tapping a hire opens its detail screen', (tester) async {
    await _show(tester, FakeServer(allHires: [hireJson(id: 7, customer: 'ZZZ Tap Me')]));

    await tester.tap(find.text('ZZZ Tap Me'));
    await tester.pumpAndSettle();

    expect(find.byType(HireDetailScreen), findsOneWidget);
  });

  testWidgets('the New Hire FAB opens the booking form with no vehicle preset', (tester) async {
    await _show(tester, FakeServer());

    await tester.tap(find.byKey(const Key('new-hire')));
    await tester.pumpAndSettle();

    final form = tester.widget<HireFormScreen>(find.byType(HireFormScreen));
    expect(form.vehicle, isNull);
  });

  testWidgets('the FAB is hidden without canCreateHires', (tester) async {
    await _show(tester, FakeServer()..canCreateHires = false);

    expect(find.byKey(const Key('new-hire')), findsNothing);
  });

  group('filters', () {
    testWidgets('the filter button opens a sheet with driver, vehicle, customer and date fields', (tester) async {
      await _show(tester, FakeServer(allHires: [hireJson(id: 1)]));

      await tester.tap(find.byKey(const Key('hire-filters')));
      await tester.pumpAndSettle();

      expect(find.text('Filter hires'), findsOneWidget);
      expect(find.byKey(const Key('filter-driver')), findsOneWidget);
      expect(find.byKey(const Key('filter-vehicle')), findsOneWidget);
      expect(find.byKey(const Key('filter-customer')), findsOneWidget);
      expect(find.byKey(const Key('filter-date-from')), findsOneWidget);
      expect(find.byKey(const Key('filter-date-to')), findsOneWidget);
    });

    testWidgets('filtering by driver sends driver_id and narrows the list', (tester) async {
      final server = FakeServer(
        allHires: [
          hireJson(id: 1, customer: 'ZZZ Nimal Hire', driverId: 11, driver: 'ZZZ Nimal'),
          hireJson(id: 2, customer: 'ZZZ Kamal Hire', driverId: 12, driver: 'ZZZ Kamal'),
        ],
        referenceDrivers: [
          {'id': 11, 'name': 'ZZZ Nimal'},
          {'id': 12, 'name': 'ZZZ Kamal'},
        ],
      );
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('hire-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-driver')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ZZZ Nimal').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-apply')));
      await tester.pumpAndSettle();

      final requests = server.requestsTo('/api/admin/hires');
      expect(requests.last.url.queryParameters['driver_id'], '11');
      expect(find.text('ZZZ Nimal Hire'), findsOneWidget);
      expect(find.text('ZZZ Kamal Hire'), findsNothing);
    });

    testWidgets('filtering by vehicle sends vehicle_id and narrows the list', (tester) async {
      final server = FakeServer(
        vehicles: [vehicleJson(id: 21, model: 'ZZZ Prius'), vehicleJson(id: 22, model: 'ZZZ Axio')],
        allHires: [
          hireJson(id: 1, customer: 'ZZZ Prius Hire', vehicleId: 21),
          hireJson(id: 2, customer: 'ZZZ Axio Hire', vehicleId: 22),
        ],
      );
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('hire-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-vehicle')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ZZZ Prius').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-apply')));
      await tester.pumpAndSettle();

      final requests = server.requestsTo('/api/admin/hires');
      expect(requests.last.url.queryParameters['vehicle_id'], '21');
      expect(find.text('ZZZ Prius Hire'), findsOneWidget);
      expect(find.text('ZZZ Axio Hire'), findsNothing);
    });

    testWidgets('filtering by customer sends customer_id and narrows the list', (tester) async {
      final server = FakeServer(
        allHires: [
          hireJson(id: 1, customer: 'ZZZ Amal', customerId: 31),
          hireJson(id: 2, customer: 'ZZZ Bimal', customerId: 32),
        ],
        referenceCustomers: [
          {'id': 31, 'name': 'ZZZ Amal', 'phone': '0770000000'},
          {'id': 32, 'name': 'ZZZ Bimal', 'phone': '0770000001'},
        ],
      );
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('hire-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-customer')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ZZZ Amal').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-apply')));
      await tester.pumpAndSettle();

      final requests = server.requestsTo('/api/admin/hires');
      expect(requests.last.url.queryParameters['customer_id'], '31');
      expect(find.text('ZZZ Amal'), findsOneWidget);
      expect(find.text('ZZZ Bimal'), findsNothing);
    });

    testWidgets('picking a date range sends date_from and date_to', (tester) async {
      final server = FakeServer(allHires: [hireJson(id: 1)]);
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('hire-filters')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter-date-from')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter-date-to')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('filter-apply')));
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final today =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final requests = server.requestsTo('/api/admin/hires');
      expect(requests.last.url.queryParameters['date_from'], today);
      expect(requests.last.url.queryParameters['date_to'], today);
    });

    testWidgets('the filter icon badge reflects the active filter count, and Clear all resets it', (tester) async {
      final server = FakeServer(
        allHires: [hireJson(id: 1, driverId: 11, driver: 'ZZZ Nimal')],
        referenceDrivers: [
          {'id': 11, 'name': 'ZZZ Nimal'},
        ],
      );
      await _show(tester, server);

      Badge badge() => tester.widget<Badge>(
            find.descendant(of: find.byKey(const Key('hire-filters')), matching: find.byType(Badge)),
          );
      expect(badge().isLabelVisible, isFalse);

      await tester.tap(find.byKey(const Key('hire-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-driver')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ZZZ Nimal').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-apply')));
      await tester.pumpAndSettle();

      expect(badge().isLabelVisible, isTrue);

      await tester.tap(find.byKey(const Key('hire-filters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('filter-clear')));
      await tester.tap(find.byKey(const Key('filter-apply')));
      await tester.pumpAndSettle();

      expect(badge().isLabelVisible, isFalse);
      final requests = server.requestsTo('/api/admin/hires');
      expect(requests.last.url.queryParameters['driver_id'], isNull);
    });
  });
}
