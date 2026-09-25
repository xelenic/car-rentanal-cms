import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/models/vehicle.dart';
import 'package:admin_app/screens/vehicle_detail_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

/// A van with one hire in each tab (two in "completed"), its numbers to match.
FakeServer _vanWithHires({int pageSize = 20, bool canCreateHires = true}) {
  final stats = vehicleStatsJson(
    hireCount: 5,
    full: 500000,
    our: 400000,
    monthCount: 2,
    monthFull: 200000,
    all: 6,
    today: 1,
    scheduled: 1,
    completed: 2,
    cancelled: 1,
    running: 1,
  );

  return FakeServer(
    pageSize: pageSize,
    canCreateHires: canCreateHires,
    vehicles: [vehicleJson(id: 1, model: 'ZZZ Test Van', condition: 'Excellent', seats: 9, pax: 8, description: 'ZZZ roomy', stats: stats)],
    hires: {
      1: [
        hireJson(id: 11, vehicleId: 1, tab: 'today', customer: 'ZZZ Today Customer', status: 'started', driver: 'ZZZ Test Driver'),
        hireJson(id: 12, vehicleId: 1, tab: 'scheduled', customer: 'ZZZ Later Customer', startTime: '2026-12-01T09:00:00+00:00'),
        hireJson(id: 13, vehicleId: 1, tab: 'completed', customer: 'ZZZ Done Customer', status: 'completed'),
        hireJson(id: 14, vehicleId: 1, tab: 'completed', customer: 'ZZZ Older Customer', status: 'completed'),
        hireJson(id: 15, vehicleId: 1, tab: 'cancelled', customer: 'ZZZ Off Customer', status: 'cancelled', cancelReason: 'ZZZ plans changed'),
      ],
    },
  );
}

/// [settle] false is for a list with more pages to come: its bottom spinner
/// never stops, so waiting for the screen to go quiet would wait forever.
AdminUser _user({bool canCreateHires = true}) => AdminUser(
      id: 1,
      name: 'ZZZ Test Admin',
      email: 'zzz@example.test',
      canCreateHires: canCreateHires,
      canUpdateHires: true,
      canDeleteHires: true,
    );

Future<void> _show(WidgetTester tester, FakeServer server, {bool canCreateHires = true, bool settle = true}) async {
  tester.view.physicalSize = const Size(412, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(
    theme: buildAdminAppTheme(),
    home: VehicleDetailScreen(
      vehicle: Vehicle.fromJson(server.vehicles.first),
      user: _user(canCreateHires: canCreateHires),
    ),
  ));
  await _quiet(tester, settle);
}

Future<void> _quiet(WidgetTester tester, bool settle) async {
  if (settle) {
    await tester.pumpAndSettle();
    return;
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _openTab(WidgetTester tester, String apiValue, {bool settle = true}) async {
  // On a phone the five tabs don't all fit, so the tab bar scrolls sideways.
  await tester.ensureVisible(find.byKey(Key('tab-$apiValue')));
  await _quiet(tester, settle);
  await tester.tap(find.byKey(Key('tab-$apiValue')));
  await _quiet(tester, settle);
}

Iterable<String?> _tabsAsked(FakeServer server) =>
    server.requestsTo('/api/admin/vehicles/1/hires').map((r) => r.url.queryParameters['tab']);

void main() {
  testWidgets('shows the vehicle and its numbers above the hires', (tester) async {
    await _show(tester, _vanWithHires());

    final header = find.byKey(const Key('vehicle-header'));
    expect(find.descendant(of: header, matching: find.text('9 seats · 8 passengers')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('Excellent')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('ZZZ roomy')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('1 running now')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('Rs. 500,000')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('Rs. 400,000')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('Rs. 100,000')), findsOneWidget);
    expect(find.text('ZZZ Test Van'), findsOneWidget); // title
  });

  testWidgets('has the five tabs, each with its count', (tester) async {
    await _show(tester, _vanWithHires());

    for (final entry in {'all': '6', 'today': '1', 'scheduled': '1', 'completed': '2', 'cancelled': '1'}.entries) {
      final tab = find.byKey(Key('tab-${entry.key}'));
      expect(tab, findsOneWidget, reason: entry.key);
      expect(find.descendant(of: tab, matching: find.text(entry.value)), findsOneWidget, reason: entry.key);
    }
    for (final entry in {'all': 'All', 'today': 'Today', 'scheduled': 'Scheduled', 'completed': 'Completed', 'cancelled': 'Cancelled'}.entries) {
      expect(find.descendant(of: find.byKey(Key('tab-${entry.key}')), matching: find.text(entry.value)), findsOneWidget);
    }
  });

  testWidgets('opens on All with every assigned hire', (tester) async {
    final server = _vanWithHires();
    await _show(tester, server);

    expect(_tabsAsked(server).first, 'all');
    for (final name in ['ZZZ Today Customer', 'ZZZ Later Customer', 'ZZZ Done Customer', 'ZZZ Older Customer', 'ZZZ Off Customer']) {
      expect(find.text(name), findsOneWidget, reason: name);
    }
  });

  testWidgets('each tab asks the server for its own hires and shows only those', (tester) async {
    final server = _vanWithHires();
    await _show(tester, server);

    await _openTab(tester, 'today');
    expect(find.text('ZZZ Today Customer'), findsOneWidget);
    expect(find.text('ZZZ Later Customer'), findsNothing);

    await _openTab(tester, 'scheduled');
    expect(find.text('ZZZ Later Customer'), findsOneWidget);
    expect(find.text('ZZZ Today Customer'), findsNothing);

    await _openTab(tester, 'completed');
    expect(find.text('ZZZ Done Customer'), findsOneWidget);
    expect(find.text('ZZZ Older Customer'), findsOneWidget);
    expect(find.text('ZZZ Later Customer'), findsNothing);

    await _openTab(tester, 'cancelled');
    expect(find.text('ZZZ Off Customer'), findsOneWidget);
    expect(find.text('ZZZ Done Customer'), findsNothing);

    expect(_tabsAsked(server).toSet(), {'all', 'today', 'scheduled', 'completed', 'cancelled'});
  });

  testWidgets('a tab is loaded once and kept while you look at others', (tester) async {
    final server = _vanWithHires();
    await _show(tester, server);

    await _openTab(tester, 'today');
    await _openTab(tester, 'all');
    await _openTab(tester, 'today');

    expect(_tabsAsked(server).where((t) => t == 'today'), hasLength(1));
    expect(_tabsAsked(server).where((t) => t == 'all'), hasLength(1));
  });

  testWidgets('a cancelled hire shows why it was cancelled', (tester) async {
    await _show(tester, _vanWithHires());

    await _openTab(tester, 'cancelled');

    expect(find.text('ZZZ plans changed'), findsOneWidget);
    expect(find.text('Cancelled'), findsWidgets);
  });

  testWidgets('a hire card shows who is driving it', (tester) async {
    await _show(tester, _vanWithHires());

    await _openTab(tester, 'today');

    expect(find.text('ZZZ Test Driver'), findsOneWidget);
    expect(find.text('Driver Hire Started'), findsOneWidget);
  });

  testWidgets('an empty tab says so', (tester) async {
    final server = _vanWithHires();
    server.hires[1] = [server.hires[1]!.first]; // only the one today hire remains
    await _show(tester, server);

    await _openTab(tester, 'scheduled');

    expect(find.text('Nothing scheduled'), findsOneWidget);
    expect(find.text('Hires booked for a later day will show up here.'), findsOneWidget);
  });

  testWidgets('a failed tab shows the message and retries', (tester) async {
    final server = _vanWithHires();
    await _show(tester, server);

    server.failWith = 500;
    await _openTab(tester, 'completed');
    expect(find.text('The server said no.'), findsOneWidget);

    server.failWith = null;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('ZZZ Done Customer'), findsOneWidget);
  });

  testWidgets('pages a long tab as you scroll', (tester) async {
    final server = _vanWithHires(pageSize: 3);
    server.hires[1] = [
      for (var i = 1; i <= 8; i++) hireJson(id: i, vehicleId: 1, tab: 'completed', customer: 'ZZZ Customer $i', status: 'completed'),
    ];
    await _show(tester, server, settle: false);
    await _openTab(tester, 'completed', settle: false);

    Iterable<String?> pages() => server
        .requestsTo('/api/admin/vehicles/1/hires')
        .where((r) => r.url.queryParameters['tab'] == 'completed')
        .map((r) => r.url.queryParameters['page']);

    expect(pages(), ['1']);

    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await _quiet(tester, false);
    expect(pages(), ['1', '2']);

    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await _quiet(tester, false);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await _quiet(tester, false);
    expect(pages(), ['1', '2', '3']);
    expect(find.text('ZZZ Customer 8'), findsOneWidget);
  });

  testWidgets('a hire opens its details', (tester) async {
    final server = _vanWithHires();
    await _show(tester, server);

    await tester.tap(find.text('ZZZ Later Customer'));
    await tester.pumpAndSettle();

    expect(find.text('Hire #12'), findsOneWidget);
    expect(server.paths, contains('/api/admin/hires/12'));
  });

  testWidgets('pulling down refreshes the list and the vehicle\'s numbers', (tester) async {
    final server = _vanWithHires();
    await _show(tester, server);
    final vehicleAsks = server.requestsTo('/api/admin/vehicles/1').length;

    await tester.fling(find.text('ZZZ Today Customer'), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(_tabsAsked(server).where((t) => t == 'all'), hasLength(2));
    expect(server.requestsTo('/api/admin/vehicles/1').length, greaterThan(vehicleAsks));
  });

  group('New Hire', () {
    testWidgets('is offered to someone who may create hires', (tester) async {
      await _show(tester, _vanWithHires());

      expect(find.byKey(const Key('new-hire')), findsOneWidget);
    });

    testWidgets('is not offered to someone who may not', (tester) async {
      await _show(tester, _vanWithHires(), canCreateHires: false);

      expect(find.byKey(const Key('new-hire')), findsNothing);
    });

    testWidgets('opens a form with this vehicle fixed and no vehicle to choose', (tester) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = _vanWithHires();
      await server.install();
      await tester.pumpWidget(MaterialApp(
        theme: buildAdminAppTheme(),
        home: VehicleDetailScreen(vehicle: Vehicle.fromJson(server.vehicles.first), user: _user()),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('new-hire')));
      await tester.pumpAndSettle();

      expect(find.text('New Hire'), findsWidgets);
      expect(find.byKey(const Key('locked-vehicle')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('locked-vehicle')), matching: find.text('ZZZ Test Van')), findsOneWidget);
      expect(find.text('No vehicle assigned'), findsNothing);
      expect(find.text('Driver (optional)'), findsOneWidget);
    });

    testWidgets('books the hire on this vehicle, then shows it and updates the counts', (tester) async {
      tester.view.physicalSize = const Size(412, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final server = _vanWithHires();
      await server.install();
      await tester.pumpWidget(MaterialApp(
        theme: buildAdminAppTheme(),
        home: VehicleDetailScreen(vehicle: Vehicle.fromJson(server.vehicles.first), user: _user()),
      ));
      await tester.pumpAndSettle();
      await _openTab(tester, 'completed'); // somewhere other than where the new hire will land

      await tester.tap(find.byKey(const Key('new-hire')));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('ZZZ Test Customer · 0770000000').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextFormField, 'From location'), 'ZZZ Pickup Place');
      await tester.enterText(find.widgetWithText(TextFormField, 'To location'), 'ZZZ Drop Place');
      await tester.enterText(find.widgetWithText(TextFormField, 'Hire full value (Rs.)'), '25000');
      await tester.enterText(find.widgetWithText(TextFormField, 'Our hire value (Rs.)'), '20000');
      await tester.pump(const Duration(milliseconds: 500));

      final create = find.widgetWithText(ElevatedButton, 'Create Hire');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(server.createdHires, hasLength(1));
      final sent = server.createdHires.single;
      expect(sent['vehicle_id'], 1);
      expect(sent['customer_id'], 1);
      expect(sent['from_location_name'], 'ZZZ Pickup Place');
      expect(sent['to_location_name'], 'ZZZ Drop Place');
      expect(sent['hire_full_value'], '25000');

      // Back on the vehicle's page, on the tab the hire belongs to (no date → Today).
      expect(find.byKey(const Key('vehicle-header')), findsOneWidget);
      expect(find.text('ZZZ Pickup Place → ZZZ Drop Place'), findsOneWidget);
      final today = find.byKey(const Key('tab-today'));
      expect(find.descendant(of: today, matching: find.text('2')), findsOneWidget); // was 1
      final all = find.byKey(const Key('tab-all'));
      expect(find.descendant(of: all, matching: find.text('7')), findsOneWidget); // was 6
    });
  });
}
