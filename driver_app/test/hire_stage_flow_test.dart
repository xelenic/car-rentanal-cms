import 'dart:async';

import 'package:driver_app/models/hire.dart';
import 'package:driver_app/screens/hire_detail_screen.dart';
import 'package:driver_app/services/pickup_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _MemoryPickupStore implements PickupStore {
  final Set<int> ids;
  _MemoryPickupStore([Iterable<int> ids = const []]) : ids = ids.toSet();

  @override
  Future<bool> isPickedUp(int hireId) async => ids.contains(hireId);
  @override
  Future<void> markPickedUp(int hireId) async => ids.add(hireId);
  @override
  Future<void> clear(int hireId) async => ids.remove(hireId);
}

// The pickup location used by the arrival tests.
const _pickupLat = 6.9344;
const _pickupLng = 79.8428;

Hire _hire({
  String status = 'pending',
  bool isTracking = false,
  DateTime? trackingStartedAt,
  bool withCoordinates = true,
}) =>
    Hire(
      id: 7,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Drop and Pickup',
      fromLocation: 'Colombo Fort',
      toLocation: 'Ella',
      pickupLocationName: withCoordinates ? 'Colombo Fort' : null,
      pickupLatitude: withCoordinates ? _pickupLat : null,
      pickupLongitude: withCoordinates ? _pickupLng : null,
      hireFullValue: 95,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      vehicle: 'Hiace',
      status: status,
      isTracking: isTracking,
      trackingStartedAt: trackingStartedAt,
    );

Position _position(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// The screen keeps animating (the button breathes), so settle by pumping a
/// few frames rather than waiting for everything to stop.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _show(
  WidgetTester tester,
  Hire hire, {
  PickupStore? store,
  StreamController<Position>? positions,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: HireDetailScreen(
      hire: hire,
      pickupStore: store ?? _MemoryPickupStore(),
      positionStream: positions == null ? null : () => positions.stream,
    ),
  ));
  await _settle(tester);
}

Future<void> _hide(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

// Run as iOS so the Android-only background service isn't involved.
final _iosOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  group('scenario 1 — before the hire starts', () {
    testWidgets('shows only the Pickup button', (tester) async {
      await _show(tester, _hire());

      expect(find.text('PICKUP'), findsOneWidget);
      expect(find.text('START'), findsNothing);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Complete Hire'), findsNothing);
      expect(find.text('Not started'), findsOneWidget);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('tapping Pickup remembers it and reveals the Start button', (tester) async {
      final store = _MemoryPickupStore();
      await _show(tester, _hire(), store: store, positions: StreamController<Position>.broadcast());

      await tester.tap(find.text('PICKUP'));
      await _settle(tester);

      expect(store.ids, contains(7));
      expect(find.text('START'), findsOneWidget);
      expect(find.text('PICKUP'), findsNothing);
      expect(find.text('Complete Hire'), findsNothing);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('a hire scheduled for later can be picked up early, but Start stays locked', (tester) async {
      final store = _MemoryPickupStore();
      final scheduled = Hire(
        id: 7,
        tourType: 'drop_pickup',
        tourTypeLabel: 'Drop and Pickup',
        hireFullValue: 95,
        paymentType: 'cash',
        paymentTypeLabel: 'Cash',
        startTime: DateTime.now().add(const Duration(days: 2)),
      );

      await _show(tester, scheduled, store: store);
      expect(find.text('PICKUP'), findsOneWidget); // not locked

      await tester.tap(find.text('PICKUP'));
      await _settle(tester);

      expect(find.text('LOCKED'), findsOneWidget); // Start is locked until the date

      await _hide(tester);
    }, variant: _iosOnly);
  });

  group('scenario 2 — picked up, ready to start', () {
    testWidgets('shows the Start button (no Pickup, Stop or Complete yet)', (tester) async {
      await _show(tester, _hire(), store: _MemoryPickupStore([7]), positions: StreamController<Position>.broadcast());

      expect(find.text('START'), findsOneWidget);
      expect(find.text('PICKUP'), findsNothing);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('Complete Hire'), findsNothing);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('highlights Start when the driver reaches the assigned location', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(), store: _MemoryPickupStore([7]), positions: positions);

      // Far away first: about 1.1 km north of the pickup point.
      positions.add(_position(_pickupLat + 0.01, _pickupLng));
      await _settle(tester);

      expect(find.text('START'), findsOneWidget);
      expect(find.text('TAP TO START'), findsNothing);
      expect(find.textContaining('away'), findsOneWidget);
      expect(find.text('Ready to start'), findsOneWidget);

      // Then arrive (about 50 m away).
      positions.add(_position(_pickupLat + 0.00045, _pickupLng));
      await _settle(tester);

      expect(find.text('TAP TO START'), findsOneWidget);
      expect(find.text("You've arrived at Colombo Fort — tap Start."), findsOneWidget);
      expect(find.text('You have arrived'), findsOneWidget);

      // Driving off again un-highlights it.
      positions.add(_position(_pickupLat + 0.01, _pickupLng));
      await _settle(tester);

      expect(find.text('TAP TO START'), findsNothing);
      expect(find.text('START'), findsOneWidget);

      await _hide(tester);
      unawaited(positions.close());
    }, variant: _iosOnly);

    testWidgets('without saved coordinates there is nothing to highlight — Start still works', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(
        tester,
        _hire(withCoordinates: false),
        store: _MemoryPickupStore([7]),
        positions: positions,
      );

      expect(positions.hasListener, isFalse); // no GPS watching at all
      expect(find.text('START'), findsOneWidget);
      expect(find.text('Tap Start when you reach the pickup location.'), findsOneWidget);

      await _hide(tester);
      unawaited(positions.close());
    }, variant: _iosOnly);

    testWidgets('the GPS is only watched while the Start button is showing', (tester) async {
      final positions = StreamController<Position>.broadcast();

      await _show(tester, _hire(), positions: positions); // still at Pickup
      expect(positions.hasListener, isFalse);

      await tester.tap(find.text('PICKUP'));
      await _settle(tester);
      expect(positions.hasListener, isTrue);

      await _hide(tester); // leaving the screen stops it
      expect(positions.hasListener, isFalse);
      unawaited(positions.close());
    }, variant: _iosOnly);
  });

  group('scenario 3 — hire running', () {
    final started = DateTime(2026, 9, 24, 8);

    testWidgets('shows the Stop and Complete Hire buttons', (tester) async {
      await _show(
        tester,
        _hire(status: 'started', isTracking: true, trackingStartedAt: started),
        store: _MemoryPickupStore([7]),
      );

      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('Complete Hire'), findsOneWidget);
      expect(find.text('TRACKING'), findsOneWidget);
      expect(find.text('PICKUP'), findsNothing);
      expect(find.text('START'), findsNothing);
      expect(find.text('Tracking active'), findsOneWidget);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('an already-running hire never asks for Pickup, even with no saved mark', (tester) async {
      await _show(tester, _hire(status: 'started', isTracking: true, trackingStartedAt: started));

      expect(find.text('PICKUP'), findsNothing);
      expect(find.text('Stop'), findsOneWidget);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('Complete Hire asks for confirmation first', (tester) async {
      await _show(tester, _hire(status: 'started', isTracking: true, trackingStartedAt: started));

      await tester.tap(find.text('Complete Hire'));
      await _settle(tester);

      expect(find.text('Complete this hire?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      expect(find.text('Complete this hire?'), findsNothing);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('a stopped (paused) hire offers Start to resume and can still be completed', (tester) async {
      await _show(tester, _hire(status: 'started', trackingStartedAt: started));

      expect(find.text('START'), findsOneWidget);
      expect(find.text('Complete Hire'), findsOneWidget);
      expect(find.text('Stop'), findsNothing);
      expect(find.text('PICKUP'), findsNothing);
      expect(find.text('Tracking paused'), findsOneWidget);

      await _hide(tester);
    }, variant: _iosOnly);
  });

  testWidgets('a completed hire shows no action buttons, only the completed banner', (tester) async {
    await _show(tester, _hire(status: 'completed'));

    expect(find.text('Hire Completed'), findsOneWidget);
    expect(find.text('PICKUP'), findsNothing);
    expect(find.text('START'), findsNothing);
    expect(find.text('Stop'), findsNothing);
    expect(find.text('Complete Hire'), findsNothing);

    await _hide(tester);
  }, variant: _iosOnly);
}
