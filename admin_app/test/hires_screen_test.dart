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

  // Overview is the default (leading) tab; most callers want the hire list.
  await tester.tap(find.byKey(const Key('tab-all')));
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

  testWidgets('shows this month\'s profit summary on its own Overview tab', (tester) async {
    await _show(
      tester,
      FakeServer(
        allHires: [hireJson(id: 1)],
        dashboard: defaultDashboardJson()
          ..['summary'] = {
            'hire_full_value_total': 10000,
            'our_hire_value_total': 7000,
            'commission_total': 3000,
            'expenses_total': 500,
            'salary_total': 1300,
            'profit_total': 5200,
          },
      ),
    );

    // Not shown on the default "All" tab — it lives on its own tab instead.
    expect(find.byKey(const Key('hires-summary-profit')), findsNothing);

    await tester.ensureVisible(find.byKey(const Key('tab-overview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-overview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hires-summary-profit')), findsOneWidget);
    expect(find.text('Rs. 5,200.00'), findsOneWidget);
    expect(find.text('Total Our Hire Value'), findsOneWidget);
    expect(find.text('Total Full Value'), findsOneWidget);
    expect(find.text('Total Expenses'), findsOneWidget);
    expect(find.text('Total Driver Salary'), findsOneWidget);
  });

  testWidgets('the Overview tab shows a retry option when the dashboard fails to load', (tester) async {
    await _show(tester, FakeServer(allHires: [hireJson(id: 1)])..failWith = 500);

    await tester.ensureVisible(find.byKey(const Key('tab-overview')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-overview')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hires-summary-profit')), findsNothing);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('shows an empty state with no hires yet', (tester) async {
    await _show(tester, FakeServer());

    expect(find.text('No hires yet'), findsOneWidget);
    expect(find.text('Hires you book will show up here.'), findsOneWidget);
  });

  testWidgets('says no hires match instead, when a search finds nothing', (tester) async {
    final server = FakeServer(allHires: [hireJson(id: 1, customer: 'ZZZ Findable')]);
    await _show(tester, server);

    await tester.enterText(find.byKey(const Key('hire-search')), 'ZZZ Nothing Like This');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('No hires match'), findsOneWidget);
    expect(find.text('Try a different search or filter.'), findsOneWidget);
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

  group('status tabs', () {
    testWidgets('shows a tab for each status, with counts for all of them', (tester) async {
      final now = DateTime.now();
      await _show(
        tester,
        FakeServer(allHires: [
          hireJson(
            id: 1,
            customer: 'ZZZ Today Hire',
            status: 'pending',
            startTime: now.subtract(const Duration(hours: 2)).toIso8601String(),
          ),
          hireJson(
            id: 2,
            customer: 'ZZZ Scheduled Hire',
            status: 'pending',
            startTime: now.add(const Duration(days: 3)).toIso8601String(),
          ),
          hireJson(
            id: 3,
            customer: 'ZZZ Completed Hire',
            status: 'completed',
            startTime: now.subtract(const Duration(days: 3)).toIso8601String(),
          ),
          hireJson(
            id: 4,
            customer: 'ZZZ Cancelled Hire',
            status: 'cancelled',
            startTime: now.subtract(const Duration(days: 3)).toIso8601String(),
          ),
        ]),
      );

      Finder inTabBar(String text) => find.descendant(of: find.byType(TabBar), matching: find.text(text));

      expect(inTabBar('All'), findsOneWidget);
      expect(inTabBar('Today'), findsOneWidget);
      expect(inTabBar('Scheduled'), findsOneWidget);
      expect(inTabBar('Completed'), findsOneWidget);
      expect(inTabBar('Cancelled'), findsOneWidget);
      expect(inTabBar('4'), findsOneWidget); // All's badge
      expect(inTabBar('1'), findsNWidgets(4)); // the other four tabs, one hire each

      // The default "All" tab shows every hire.
      expect(find.text('ZZZ Today Hire'), findsOneWidget);
      expect(find.text('ZZZ Cancelled Hire'), findsOneWidget);
    });

    testWidgets('tapping a tab shows only that tab\'s hires', (tester) async {
      final now = DateTime.now();
      await _show(
        tester,
        FakeServer(allHires: [
          hireJson(
            id: 1,
            customer: 'ZZZ Today Hire',
            status: 'pending',
            startTime: now.subtract(const Duration(hours: 2)).toIso8601String(),
          ),
          hireJson(
            id: 3,
            customer: 'ZZZ Completed Hire',
            status: 'completed',
            startTime: now.subtract(const Duration(days: 3)).toIso8601String(),
          ),
        ]),
      );

      await tester.ensureVisible(find.byKey(const Key('tab-completed')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-completed')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Completed Hire'), findsOneWidget);
      expect(find.text('ZZZ Today Hire'), findsNothing);
    });

    testWidgets('an empty tab shows its own empty message', (tester) async {
      await _show(tester, FakeServer());

      await tester.ensureVisible(find.byKey(const Key('tab-cancelled')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-cancelled')));
      await tester.pumpAndSettle();

      expect(find.text('No cancelled hires'), findsOneWidget);
    });
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

    testWidgets('a driver/vehicle/customer/date filter narrows every tab, not just All', (tester) async {
      final server = FakeServer(
        allHires: [
          hireJson(id: 1, customer: 'ZZZ Nimal Hire', driverId: 11, driver: 'ZZZ Nimal', status: 'completed'),
          hireJson(id: 2, customer: 'ZZZ Kamal Hire', driverId: 12, driver: 'ZZZ Kamal', status: 'completed'),
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

      await tester.ensureVisible(find.byKey(const Key('tab-completed')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tab-completed')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Nimal Hire'), findsOneWidget);
      expect(find.text('ZZZ Kamal Hire'), findsNothing);
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
