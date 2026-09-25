import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/models/vehicle.dart';
import 'package:admin_app/screens/vehicle_detail_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

const _user = AdminUser(id: 1, name: 'ZZZ', email: 'zzz@example.test', canCreateHires: true, canUpdateHires: true, canDeleteHires: true);

/// A van with hires in September and August 2026 and one in December 2025.
FakeServer _van() {
  final all = vehicleStatsJson(hireCount: 5, full: 500000, our: 400000, monthCount: 2, monthFull: 120000, all: 5, today: 1, completed: 3, cancelled: 1);

  return FakeServer(
    vehicles: [vehicleJson(id: 1, model: 'ZZZ Test Van', stats: all)],
    periods: {
      1: {
        'years': [2026, 2025],
        'months_by_year': {'2026': [9, 8], '2025': [12]},
      },
    },
    statsByPeriod: {
      '2026-9': vehicleStatsJson(hireCount: 2, full: 150000, our: 120000, monthCount: 2, monthFull: 120000, all: 2, today: 1, completed: 1),
      '2026-8': vehicleStatsJson(hireCount: 1, full: 90000, our: 70000, monthCount: 2, monthFull: 120000, all: 2, completed: 1, cancelled: 1),
      '2026': vehicleStatsJson(hireCount: 4, full: 400000, our: 320000, monthCount: 2, monthFull: 120000, all: 4, today: 1, completed: 2, cancelled: 1),
    },
    hires: {
      1: [
        hireJson(id: 21, vehicleId: 1, tab: 'today', customer: 'ZZZ Sep Today', startTime: '2026-09-25T09:00:00+00:00'),
        hireJson(id: 22, vehicleId: 1, tab: 'completed', customer: 'ZZZ Sep Done', status: 'completed', startTime: '2026-09-03T09:00:00+00:00'),
        hireJson(id: 23, vehicleId: 1, tab: 'completed', customer: 'ZZZ Aug Done', status: 'completed', startTime: '2026-08-30T09:00:00+00:00'),
        hireJson(id: 24, vehicleId: 1, tab: 'cancelled', customer: 'ZZZ Aug Off', status: 'cancelled', startTime: '2026-08-12T09:00:00+00:00'),
        hireJson(id: 25, vehicleId: 1, tab: 'completed', customer: 'ZZZ Last Year', status: 'completed', startTime: '2025-12-20T09:00:00+00:00'),
      ],
    },
  );
}

Future<void> _show(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(
    theme: buildAdminAppTheme(),
    home: VehicleDetailScreen(vehicle: Vehicle.fromJson(server.vehicles.first), user: _user),
  ));
  await tester.pumpAndSettle();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('period-filter')));
  await tester.pumpAndSettle();
}

/// The tab bar scrolls sideways when the tabs don't all fit, so bring one into view first.
Future<void> _openTab(WidgetTester tester, String apiValue) async {
  await tester.ensureVisible(find.byKey(Key('tab-$apiValue')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('tab-$apiValue')));
  await tester.pumpAndSettle();
}

Future<void> _pick(WidgetTester tester, String dropdownKey, String option) async {
  await tester.tap(find.byKey(Key(dropdownKey)));
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

Future<void> _filterTo(WidgetTester tester, {required String year, String? month}) async {
  await _openSheet(tester);
  await _pick(tester, 'period-year', year);
  if (month != null) await _pick(tester, 'period-month-${int.parse(year)}', month);
  await tester.tap(find.byKey(const Key('period-apply')));
  await tester.pumpAndSettle();
}

Iterable<Map<String, String>> _hireQueries(FakeServer server) =>
    server.requestsTo('/api/admin/vehicles/1/hires').map((r) => r.url.queryParameters);

void main() {
  testWidgets('starts unfiltered, with the filter button and this month\'s line', (tester) async {
    final server = _van();
    await _show(tester, server);

    expect(find.byKey(const Key('period-filter')), findsOneWidget);
    expect(find.byKey(const Key('period-bar')), findsNothing);
    expect(find.text('This month · 2 hires · Rs. 120,000'), findsOneWidget);
    expect(_hireQueries(server).every((q) => !q.containsKey('year')), isTrue);
  });

  testWidgets('offers the years this vehicle has hires in — and nothing before it is asked', (tester) async {
    final server = _van();
    await _show(tester, server);
    expect(server.requestsTo('/api/admin/vehicles/1/periods'), isEmpty);

    await _openSheet(tester);

    expect(server.requestsTo('/api/admin/vehicles/1/periods'), hasLength(1));
    expect(find.text('Filter by month'), findsOneWidget);
    await tester.tap(find.byKey(const Key('period-year')));
    await tester.pumpAndSettle();
    expect(find.text('All time'), findsWidgets);
    expect(find.text('2026'), findsWidgets);
    expect(find.text('2025'), findsWidgets);
    expect(find.text('2024'), findsNothing);
  });

  testWidgets('offers only the months of the chosen year that have hires', (tester) async {
    await _show(tester, _van());
    await _openSheet(tester);

    await _pick(tester, 'period-year', '2026');
    await tester.tap(find.byKey(const Key('period-month-2026')));
    await tester.pumpAndSettle();

    expect(find.text('September'), findsWidgets);
    expect(find.text('August'), findsWidgets);
    expect(find.text('Whole year'), findsWidgets);
    expect(find.text('July'), findsNothing);
    expect(find.text('December'), findsNothing); // that is 2025's
  });

  testWidgets('the month can only be picked once a year is', (tester) async {
    await _show(tester, _van());
    await _openSheet(tester);

    final month = tester.widget<DropdownButtonFormField<int?>>(find.byKey(const Key('period-month-null')));
    expect(month.onChanged, isNull);
  });

  testWidgets('filtering to a month narrows the list, the counts and the totals', (tester) async {
    final server = _van();
    await _show(tester, server);

    await _filterTo(tester, year: '2026', month: 'August');

    // What it asked for…
    expect(_hireQueries(server).last, {'tab': 'all', 'page': '1', 'year': '2026', 'month': '8'});
    expect(server.requestsTo('/api/admin/vehicles/1').last.url.queryParameters, {'year': '2026', 'month': '8'});
    // …and what it shows.
    expect(find.text('ZZZ Aug Done'), findsOneWidget);
    expect(find.text('ZZZ Aug Off'), findsOneWidget);
    expect(find.text('ZZZ Sep Today'), findsNothing);
    expect(find.text('ZZZ Last Year'), findsNothing);
    expect(find.descendant(of: find.byKey(const Key('tab-all')), matching: find.text('2')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('vehicle-header')), matching: find.text('Rs. 90,000')), findsOneWidget);
  });

  testWidgets('shows which period is on, and a dot on the filter button', (tester) async {
    await _show(tester, _van());

    await _filterTo(tester, year: '2026', month: 'September');

    final bar = find.byKey(const Key('period-bar'));
    expect(bar, findsOneWidget);
    expect(find.descendant(of: bar, matching: find.text('September 2026')), findsOneWidget);
    expect(tester.widget<Badge>(find.descendant(of: find.byKey(const Key('period-filter')), matching: find.byType(Badge))).isLabelVisible, isTrue);
  });

  testWidgets('hides the "this month" line while a period is chosen', (tester) async {
    await _show(tester, _van());

    await _filterTo(tester, year: '2026', month: 'September');

    expect(find.textContaining('This month'), findsNothing);
  });

  testWidgets('a whole year is filtered by year alone', (tester) async {
    final server = _van();
    await _show(tester, server);

    await _filterTo(tester, year: '2026');

    expect(_hireQueries(server).last, {'tab': 'all', 'page': '1', 'year': '2026'});
    expect(find.descendant(of: find.byKey(const Key('period-bar')), matching: find.text('2026')), findsOneWidget);
    expect(find.text('ZZZ Last Year'), findsNothing);
    expect(find.text('ZZZ Sep Today'), findsOneWidget);
    expect(find.text('ZZZ Aug Done'), findsOneWidget);
  });

  testWidgets('the filter stays on when you switch tabs', (tester) async {
    final server = _van();
    await _show(tester, server);
    await _filterTo(tester, year: '2026', month: 'August');

    await _openTab(tester, 'completed');

    expect(_hireQueries(server).last, {'tab': 'completed', 'page': '1', 'year': '2026', 'month': '8'});
    expect(find.text('ZZZ Aug Done'), findsOneWidget);
    expect(find.text('ZZZ Sep Done'), findsNothing);
  });

  testWidgets('a tab with nothing in the chosen period says so', (tester) async {
    await _show(tester, _van());
    await _filterTo(tester, year: '2026', month: 'August');

    await _openTab(tester, 'today');

    expect(find.text('Nothing for today'), findsOneWidget);
    expect(find.text('None in August 2026.'), findsOneWidget);
  });

  testWidgets('the chip\'s cross drops the filter and shows all time again', (tester) async {
    final server = _van();
    await _show(tester, server);
    await _filterTo(tester, year: '2026', month: 'August');

    await tester.tap(find.byTooltip('Show all time'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('period-bar')), findsNothing);
    expect(_hireQueries(server).last.containsKey('year'), isFalse);
    expect(server.requestsTo('/api/admin/vehicles/1').last.url.queryParameters, isEmpty);
    expect(find.text('ZZZ Last Year'), findsOneWidget);
    expect(find.textContaining('This month'), findsOneWidget);
  });

  testWidgets('"Show all time" in the sheet drops it too', (tester) async {
    final server = _van();
    await _show(tester, server);
    await _filterTo(tester, year: '2026', month: 'August');

    await _openSheet(tester);
    await tester.tap(find.byKey(const Key('period-clear')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('period-bar')), findsNothing);
    expect(_hireQueries(server).last.containsKey('year'), isFalse);
  });

  testWidgets('reopening the sheet shows the period that is on', (tester) async {
    await _show(tester, _van());
    await _filterTo(tester, year: '2026', month: 'August');

    await _openSheet(tester);

    expect(find.descendant(of: find.byKey(const Key('period-year')), matching: find.text('2026')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('period-month-2026')), matching: find.text('August')), findsOneWidget);
  });

  testWidgets('dismissing the sheet changes nothing', (tester) async {
    final server = _van();
    await _show(tester, server);
    final asked = server.requests.length;

    await _openSheet(tester);
    await tester.tapAt(const Offset(10, 60)); // the scrim
    await tester.pumpAndSettle();

    expect(find.text('Filter by month'), findsNothing);
    expect(find.byKey(const Key('period-bar')), findsNothing);
    expect(server.requests.length, asked + 1); // just the periods lookup
  });

  testWidgets('a vehicle with no hires has nothing to filter', (tester) async {
    final server = FakeServer(vehicles: [vehicleJson(id: 1, model: 'ZZZ Test Van')]);
    await _show(tester, server);

    await _openSheet(tester);

    expect(find.text('This vehicle has no hires yet, so there is nothing to filter.'), findsOneWidget);
    expect(find.byKey(const Key('period-apply')), findsNothing);
  });

  testWidgets('a failed lookup can be retried', (tester) async {
    final server = _van();
    await _show(tester, server);

    server.failWith = 500;
    await _openSheet(tester);
    expect(find.text('The server said no.'), findsOneWidget);

    server.failWith = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('period-year')), findsOneWidget);
  });

  testWidgets('booking a new hire drops the filter so the hire is in view', (tester) async {
    final server = _van();
    await _show(tester, server);
    await _filterTo(tester, year: '2025', month: 'December');
    expect(find.byKey(const Key('period-bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('new-hire')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ZZZ Test Customer · 0770000000').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'From location'), 'ZZZ Pickup');
    await tester.enterText(find.widgetWithText(TextFormField, 'To location'), 'ZZZ Drop');
    await tester.enterText(find.widgetWithText(TextFormField, 'Hire full value (Rs.)'), '9000');
    await tester.enterText(find.widgetWithText(TextFormField, 'Our hire value (Rs.)'), '7000');
    await tester.pump(const Duration(milliseconds: 500));
    final create = find.widgetWithText(ElevatedButton, 'Create Hire');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    expect(server.createdHires, hasLength(1));
    expect(find.byKey(const Key('period-bar')), findsNothing);
    expect(find.text('ZZZ Pickup → ZZZ Drop'), findsOneWidget);
  });
}
