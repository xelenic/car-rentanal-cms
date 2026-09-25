import 'dart:async';

import 'package:driver_app/models/hire.dart';
import 'package:driver_app/models/hire_map_point.dart';
import 'package:driver_app/models/map_role.dart';
import 'package:driver_app/models/tracking_status.dart';
import 'package:driver_app/screens/hire_detail_screen.dart';
import 'package:driver_app/services/pickup_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

import 'support/fake_google_maps.dart';

// Colombo Fort → Ella
const _pickup = HireMapPoint(role: MapRole.pickup, name: 'Colombo Fort', latitude: 6.9344, longitude: 79.8428);
const _end = HireMapPoint(role: MapRole.end, name: 'Ella', latitude: 6.8667, longitude: 81.0466);

// A round trip: it ends about 30 m from where it started.
const _sameSpot = HireMapPoint(role: MapRole.end, name: 'Colombo Fort', latitude: 6.9346, longitude: 79.8430);

class _NoPickupStore implements PickupStore {
  @override
  Future<bool> isPickedUp(int hireId) async => true;
  @override
  Future<void> markPickedUp(int hireId) async {}
  @override
  Future<void> clear(int hireId) async {}
}

Hire _hire({
  List<HireMapPoint> places = const [_pickup, _end],
  bool started = true,
  bool tracking = true,
  bool completed = false,
}) =>
    Hire(
      id: 7,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Drop and Pickup',
      hireFullValue: 95,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      pickupLocationName: 'Colombo Fort',
      pickupLatitude: 6.9344,
      pickupLongitude: 79.8428,
      mapPoints: places,
      status: completed ? 'completed' : (started ? 'started' : 'pending'),
      isTracking: tracking && !completed,
      trackingStartedAt: started ? DateTime(2026, 9, 25, 8) : null,
    );

Position _at(double lat, double lng) => Position(
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

// Ella, ~45 m away / ~2.2 km away
final _nearEnd = _at(6.8667 + 0.0004, 81.0466);
final _farFromEnd = _at(6.8667 + 0.02, 81.0466);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _show(
  WidgetTester tester,
  Hire hire,
  StreamController<Position> positions, {
  List<TrackPoint> recordedPath = const [],
}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: HireDetailScreen(
      hire: hire,
      pickupStore: _NoPickupStore(),
      positionStream: () => positions.stream,
      loadTracking: (id) async => TrackingStatus(
        status: hire.status,
        statusLabel: 'x',
        isTracking: hire.isTracking,
        totalDistanceKm: 0,
        points: recordedPath,
      ),
    ),
  ));
  await _settle(tester);
}

Future<void> _hide(WidgetTester tester, StreamController<Position> positions) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  unawaited(positions.close());
}

final _highlight = find.byKey(const Key('complete-hire-highlight'));
final _arrivedBanner = find.text("You've arrived at Ella — tap Complete Hire.");

// Run as iOS so the Android-only background service isn't involved.
final _iosOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  setUp(installFakeGoogleMaps);

  group('reaching the end location of a running hire', () {
    testWidgets('lights up Complete Hire, says why, and clears again when the driver drives off', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(), positions);

      // heading there: no highlight, just how far
      positions.add(_farFromEnd);
      await _settle(tester);
      expect(_highlight, findsNothing);
      expect(find.textContaining('Ella is'), findsOneWidget);
      expect(find.textContaining('Complete Hire lights up when you arrive'), findsOneWidget);
      expect(find.text('Tracking active'), findsOneWidget);

      // arrived
      positions.add(_nearEnd);
      await _settle(tester);
      expect(_highlight, findsOneWidget);
      expect(_arrivedBanner, findsOneWidget);
      expect(find.text('You have arrived'), findsOneWidget);
      expect(find.text('Tracking active'), findsNothing);
      expect(find.text('Complete Hire'), findsOneWidget); // the same button, now glowing

      // drove on past it
      positions.add(_farFromEnd);
      await _settle(tester);
      expect(_highlight, findsNothing);
      expect(_arrivedBanner, findsNothing);

      await _hide(tester, positions);
    }, variant: _iosOnly);

    testWidgets('the highlighted button still asks for confirmation before completing', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(), positions);
      positions.add(_nearEnd);
      await _settle(tester);

      await tester.tap(find.text('Complete Hire'));
      await _settle(tester);

      expect(find.text('Complete this hire?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await _settle(tester);
      await _hide(tester, positions);
    }, variant: _iosOnly);

    testWidgets('arriving at the pickup location no longer matters once the hire has started', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(), positions);

      positions.add(_at(6.9344, 79.8428)); // standing at the pickup
      await _settle(tester);

      expect(_highlight, findsNothing);
      expect(find.text('You have arrived'), findsNothing);

      await _hide(tester, positions);
    }, variant: _iosOnly);

    testWidgets('a multi-stop tour only lights up at the last place', (tester) async {
      const stop = HireMapPoint(role: MapRole.stop, name: 'Kandy', latitude: 7.2906, longitude: 80.6337);
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(places: const [_pickup, stop, _end]), positions);

      positions.add(_at(7.2906, 80.6337)); // at a stop on the way
      await _settle(tester);
      expect(_highlight, findsNothing);

      positions.add(_nearEnd);
      await _settle(tester);
      expect(_highlight, findsOneWidget);

      await _hide(tester, positions);
    }, variant: _iosOnly);
  });

  group('a paused hire', () {
    testWidgets('lights up Complete Hire at the end but leaves the Start button alone', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(tracking: false), positions);

      positions.add(_nearEnd);
      await _settle(tester);

      expect(_highlight, findsOneWidget);
      expect(_arrivedBanner, findsOneWidget);
      expect(find.text('TAP TO START'), findsNothing); // Start is not what to press
      expect(find.text('START'), findsOneWidget);
      expect(find.text('Tracking paused'), findsOneWidget);

      await _hide(tester, positions);
    }, variant: _iosOnly);
  });

  group('a round trip (ends where it began)', () {
    testWidgets('does not count standing at the start as arriving — only once the driver has been away', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(places: const [_pickup, _sameSpot]), positions);

      positions.add(_at(6.9345, 79.8429)); // still at the pickup, right after Start
      await _settle(tester);
      expect(_highlight, findsNothing);
      expect(find.text("You've arrived at Colombo Fort — tap Complete Hire."), findsNothing);

      positions.add(_at(7.05, 80.0)); // off on the trip
      await _settle(tester);
      expect(_highlight, findsNothing);

      positions.add(_at(6.9345, 79.8429)); // and back again
      await _settle(tester);
      expect(_highlight, findsOneWidget);
      expect(find.text("You've arrived at Colombo Fort — tap Complete Hire."), findsOneWidget);

      await _hide(tester, positions);
    }, variant: _iosOnly);

    testWidgets('remembers a trip made while the app was closed, from the path the background service recorded', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(
        tester,
        _hire(places: const [_pickup, _sameSpot]),
        positions,
        recordedPath: const [TrackPoint(lat: 6.9344, lng: 79.8428), TrackPoint(lat: 7.10, lng: 80.1), TrackPoint(lat: 6.9350, lng: 79.8430)],
      );

      positions.add(_at(6.9345, 79.8429)); // reopening the app back at the start
      await _settle(tester);

      expect(_highlight, findsOneWidget);

      await _hide(tester, positions);
    }, variant: _iosOnly);
  });

  group('nothing to arrive at', () {
    testWidgets('a running hire whose end has no saved coordinates never watches the GPS', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(places: const [_pickup]), positions);

      expect(positions.hasListener, isFalse);
      expect(_highlight, findsNothing);

      await _hide(tester, positions);
    }, variant: _iosOnly);

    testWidgets('a completed hire never watches the GPS', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(completed: true), positions);

      expect(positions.hasListener, isFalse);

      await _hide(tester, positions);
    }, variant: _iosOnly);

    testWidgets('leaving the screen stops watching', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(), positions);
      expect(positions.hasListener, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(positions.hasListener, isFalse);
      unawaited(positions.close());
    }, variant: _iosOnly);
  });
}
