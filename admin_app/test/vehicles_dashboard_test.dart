import 'package:admin_app/screens/vehicles_dashboard_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

/// [settle] false is for a fleet with more pages to come: its bottom spinner
/// never stops, so waiting for the screen to go quiet would wait forever.
Future<void> _show(WidgetTester tester, FakeServer server, {bool settle = true}) async {
  tester.view.physicalSize = const Size(412, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: const VehiclesDashboardScreen()));
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

FakeServer _fleet() => FakeServer(vehicles: [
      vehicleJson(
        id: 1,
        model: 'ZZZ Test Van',
        condition: 'Excellent',
        seats: 9,
        pax: 8,
        stats: vehicleStatsJson(hireCount: 6, full: 120000, our: 80000, all: 8, today: 2, scheduled: 1, completed: 4, cancelled: 1, running: 1),
      ),
      vehicleJson(id: 2, model: 'ZZZ Test Car', condition: 'Poor', seats: 1, pax: 1),
      vehicleJson(id: 3, model: 'ZZZ Test Bus', condition: 'Good', seats: 30, pax: 28),
    ]);

/// The chip row scrolls sideways when the labels don't all fit (the test font
/// is much wider than a phone's), so bring a chip into view before tapping it.
Future<void> _pickCondition(WidgetTester tester, String condition) async {
  final chip = find.byKey(Key('condition-$condition'));
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows each vehicle as a tile with just its icon and name', (tester) async {
    await _show(tester, _fleet());

    for (final entry in {1: 'ZZZ Test Van', 2: 'ZZZ Test Car', 3: 'ZZZ Test Bus'}.entries) {
      final tile = find.byKey(Key('vehicle-card-${entry.key}'));
      expect(tile, findsOneWidget);
      expect(find.descendant(of: tile, matching: find.text(entry.value)), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.byIcon(Icons.directions_car_filled_rounded)), findsOneWidget);
    }
  });

  testWidgets('keeps the details off the tiles — they are on the vehicle\'s page', (tester) async {
    await _show(tester, _fleet());

    // Nothing but the name and the icon: no seats, condition, money or hire counts.
    for (final id in [1, 2, 3]) {
      final texts = find.descendant(of: find.byKey(Key('vehicle-card-$id')), matching: find.byType(Text));
      expect(texts, findsOneWidget, reason: 'tile $id');
    }
    for (final detail in ['9 seats · 8 passengers', 'Rs. 120,000', 'Hire value', 'Commission', 'Today 2', '1 running now']) {
      expect(find.text(detail), findsNothing, reason: detail);
    }
    expect(find.byKey(const Key('fleet-summary')), findsNothing);
  });

  testWidgets('lays the tiles out in a grid, two to a row on a phone', (tester) async {
    await _show(tester, _fleet());

    final van = tester.getTopLeft(find.byKey(const Key('vehicle-card-1')));
    final car = tester.getTopLeft(find.byKey(const Key('vehicle-card-2')));
    final bus = tester.getTopLeft(find.byKey(const Key('vehicle-card-3')));

    expect(car.dy, van.dy); // side by side
    expect(car.dx, greaterThan(van.dx));
    expect(bus.dy, greaterThan(van.dy)); // the third wraps to the next row
    expect(bus.dx, van.dx);
  });

  testWidgets('does not list any hires — only vehicles', (tester) async {
    final server = _fleet();
    await _show(tester, server);

    expect(server.paths, isNot(contains('/api/admin/hires')));
    expect(server.paths.where((p) => p.contains('/hires')), isEmpty);
  });

  group('My Expenses', () {
    testWidgets('has a button for someone who may view them', (tester) async {
      await _show(tester, _fleet()..canViewMyExpenses = true);

      expect(find.byKey(const Key('my-expenses')), findsOneWidget);
    });

    testWidgets('has none for someone who may not', (tester) async {
      await _show(tester, _fleet()..canViewMyExpenses = false);

      expect(find.byKey(const Key('my-expenses')), findsNothing);
    });

    testWidgets('the button opens My Expenses', (tester) async {
      final server = _fleet();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('my-expenses')));
      await tester.pumpAndSettle();

      expect(find.text('My Expenses'), findsOneWidget);
      expect(find.byKey(const Key('card-my-profit')), findsOneWidget);
      expect(server.requestsTo('/api/admin/my-expenses'), isNotEmpty);
    });
  });

  testWidgets('offers Add Vehicle to someone allowed to add one', (tester) async {
    await _show(tester, _fleet()..canCreateVehicles = true);

    expect(find.byKey(const Key('add-vehicle')), findsOneWidget);
  });

  testWidgets('hides Add Vehicle from someone who may not add vehicles', (tester) async {
    await _show(tester, _fleet()..canCreateVehicles = false);

    expect(find.byKey(const Key('add-vehicle')), findsNothing);
  });

  group('the condition filter', () {
    testWidgets('offers All and every condition', (tester) async {
      await _show(tester, _fleet());

      for (final key in ['all', 'New', 'Excellent', 'Good', 'Fair', 'Poor']) {
        expect(find.byKey(Key('condition-$key')), findsOneWidget, reason: key);
      }
    });

    testWidgets('starts on All, showing every vehicle', (tester) async {
      final server = _fleet();
      await _show(tester, server);

      expect(tester.widget<ChoiceChip>(find.byKey(const Key('condition-all'))).selected, isTrue);
      expect(server.requestsTo('/api/admin/vehicles').first.url.queryParameters.containsKey('condition'), isFalse);
    });

    testWidgets('narrows the fleet to one condition, asking the server for it', (tester) async {
      final server = _fleet();
      await _show(tester, server);

      await _pickCondition(tester, 'Poor');

      expect(server.requestsTo('/api/admin/vehicles').last.url.queryParameters['condition'], 'Poor');
      expect(find.text('ZZZ Test Car'), findsOneWidget);
      expect(find.text('ZZZ Test Van'), findsNothing);
      expect(find.text('ZZZ Test Bus'), findsNothing);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('condition-Poor'))).selected, isTrue);
      expect(tester.widget<ChoiceChip>(find.byKey(const Key('condition-all'))).selected, isFalse);
    });

    testWidgets('All brings every vehicle back', (tester) async {
      final server = _fleet();
      await _show(tester, server);

      await _pickCondition(tester, 'Poor');
      await _pickCondition(tester, 'all');

      expect(server.requestsTo('/api/admin/vehicles').last.url.queryParameters.containsKey('condition'), isFalse);
      expect(find.text('ZZZ Test Van'), findsOneWidget);
      expect(find.text('ZZZ Test Car'), findsOneWidget);
      expect(find.text('ZZZ Test Bus'), findsOneWidget);
    });

    testWidgets('works together with the search', (tester) async {
      final server = _fleet();
      await _show(tester, server);

      await _pickCondition(tester, 'Good');
      await tester.enterText(find.byKey(const Key('vehicle-search')), 'bus');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final last = server.requestsTo('/api/admin/vehicles').last.url.queryParameters;
      expect(last['condition'], 'Good');
      expect(last['search'], 'bus');
      expect(find.text('ZZZ Test Bus'), findsOneWidget);
    });

    testWidgets('says so when nothing is in that condition', (tester) async {
      await _show(tester, _fleet());

      await _pickCondition(tester, 'Fair');

      expect(find.text('No vehicles match'), findsOneWidget);
      expect(find.text('Try a different search or filter.'), findsOneWidget);
    });

    testWidgets('a filter with no matches does not invite adding the first vehicle', (tester) async {
      await _show(tester, _fleet());

      await _pickCondition(tester, 'Fair');

      expect(find.text('No vehicles yet'), findsNothing);
      expect(find.widgetWithText(ElevatedButton, 'Add Vehicle'), findsNothing);
    });
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
      pageSize: 6,
      vehicles: [for (var i = 1; i <= 9; i++) vehicleJson(id: i, model: 'ZZZ Test Vehicle $i')],
    );
    await _show(tester, server, settle: false);

    expect(server.requestsTo('/api/admin/vehicles').map((r) => r.url.queryParameters['page']), ['1']);
    expect(find.text('ZZZ Test Vehicle 9', skipOffstage: false), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await _quiet(tester, false);

    expect(server.requestsTo('/api/admin/vehicles').map((r) => r.url.queryParameters['page']), ['1', '2']);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -3000));
    await _quiet(tester, true); // page 2 was the last, so the spinner is gone
    expect(find.text('ZZZ Test Vehicle 9'), findsOneWidget);
  });

  testWidgets('a tile opens that vehicle\'s page with the full details', (tester) async {
    await _show(tester, _fleet());

    await tester.tap(find.byKey(const Key('vehicle-card-1')));
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('vehicle-header'));
    expect(header, findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('9 seats · 8 passengers')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('Excellent')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('Rs. 120,000')), findsOneWidget);
    expect(find.descendant(of: header, matching: find.text('1 running now')), findsOneWidget);
    expect(find.text('ZZZ Test Van'), findsOneWidget); // the page's title
  });
}
