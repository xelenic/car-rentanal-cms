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

const _pickup = HireMapPoint(role: MapRole.pickup, name: 'Colombo Fort', latitude: 6.9344, longitude: 79.8428);
const _end = HireMapPoint(role: MapRole.end, name: 'Ella', latitude: 6.8667, longitude: 81.0466);

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

Hire _hire({
  bool started = false,
  bool tracking = false,
  String status = 'pending',
  DateTime? cancelledAt,
  String? cancelReason,
}) =>
    Hire(
      id: 7,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Drop and Pickup',
      fromLocation: 'Colombo Fort',
      toLocation: 'Ella',
      hireFullValue: 95,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      pickupLocationName: 'Colombo Fort',
      pickupLatitude: 6.9344,
      pickupLongitude: 79.8428,
      mapPoints: const [_pickup, _end],
      status: status,
      isTracking: tracking,
      trackingStartedAt: started ? DateTime(2026, 9, 25, 8) : null,
      cancelledAt: cancelledAt,
      cancelReason: cancelReason,
    );

/// What the server answers to a cancel request.
TrackingStatus _cancelledStatus() => TrackingStatus(
      status: 'cancelled',
      statusLabel: 'Cancelled',
      isTracking: false,
      trackingStoppedAt: DateTime(2026, 9, 25, 15),
      cancelledAt: DateTime(2026, 9, 25, 15, 40),
      totalDistanceKm: 3.2,
    );

class _Cancels {
  final calls = <(int, String?)>[];
  Object? failWith;

  Future<TrackingStatus> call(int hireId, String? reason) async {
    calls.add((hireId, reason));
    if (failWith != null) throw failWith!;
    return _cancelledStatus();
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _show(
  WidgetTester tester,
  Hire hire,
  _Cancels cancels, {
  bool pickedUp = false,
  StreamController<Position>? positions,
  Future<TrackingStatus> Function(int hireId)? recordPoint,
}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: HireDetailScreen(
      hire: hire,
      pickupStore: _MemoryPickupStore(pickedUp ? [7] : []),
      cancelHire: cancels.call,
      recordPoint: recordPoint,
      positionStream: positions == null ? null : () => positions.stream,
      loadTracking: (id) async => TrackingStatus(status: hire.status, statusLabel: 'x', isTracking: hire.isTracking, totalDistanceKm: 0),
    ),
  ));
  await _settle(tester);
}

Future<void> _hide(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

Future<void> _cancelWith(WidgetTester tester, {String? reason}) async {
  await tester.tap(find.text('Cancel Hire'));
  await _settle(tester);
  if (reason != null) {
    await tester.enterText(find.byKey(const Key('cancel-reason')), reason);
  }
  await tester.tap(find.text('Yes, cancel hire'));
  await _settle(tester);
}

// Run as iOS so the Android-only background service isn't involved.
final _iosOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  setUp(installFakeGoogleMaps);

  group('the Cancel Hire button', () {
    testWidgets('is offered at every stage until the hire is over', (tester) async {
      final cases = <String, Hire>{
        'before Pickup': _hire(),
        'running': _hire(started: true, tracking: true, status: 'started'),
        'paused': _hire(started: true, status: 'started'),
      };

      for (final entry in cases.entries) {
        await _show(tester, entry.value, _Cancels());
        expect(find.text('Cancel Hire'), findsOneWidget, reason: entry.key);
        expect(find.text('Stop'), findsNothing, reason: entry.key);
        await _hide(tester);
      }
    }, variant: _iosOnly);

    testWidgets('asks first — and "Keep hire" changes nothing', (tester) async {
      final cancels = _Cancels();
      await _show(tester, _hire(started: true, tracking: true, status: 'started'), cancels);

      await tester.tap(find.text('Cancel Hire'));
      await _settle(tester);

      expect(find.text('Cancel this hire?'), findsOneWidget);
      expect(find.byKey(const Key('cancel-reason')), findsOneWidget);
      expect(find.textContaining('tracking will stop'), findsOneWidget);
      expect(cancels.calls, isEmpty); // nothing sent yet

      await tester.tap(find.text('Keep hire'));
      await _settle(tester);

      expect(find.text('Cancel this hire?'), findsNothing);
      expect(cancels.calls, isEmpty);
      expect(find.text('Complete Hire'), findsOneWidget); // still a live hire

      await _hide(tester);
    }, variant: _iosOnly);
  });

  group('cancelling', () {
    testWidgets('sends the reason, then the hire shows as cancelled with nothing left to do', (tester) async {
      final cancels = _Cancels();
      await _show(tester, _hire(started: true, tracking: true, status: 'started'), cancels);

      await _cancelWith(tester, reason: '  Customer did not show up ');

      expect(cancels.calls, [(7, 'Customer did not show up')]);

      // the screen now shows a cancelled hire
      expect(find.text('Cancelled'), findsWidgets);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('Hire Cancelled'), findsOneWidget);
      expect(find.textContaining('This hire was cancelled on Sep 25, 2026'), findsOneWidget);
      expect(find.text('Reason: Customer did not show up'), findsOneWidget);
      expect(find.text('It will not continue, and tracking has stopped.'), findsOneWidget);

      // …and no way to continue it
      for (final gone in ['Cancel Hire', 'Complete Hire', 'START', 'PICKUP', 'Stop', 'TRACKING', 'Tracking active']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('the reason is optional', (tester) async {
      final cancels = _Cancels();
      await _show(tester, _hire(started: true, tracking: true, status: 'started'), cancels);

      await _cancelWith(tester);

      expect(cancels.calls, [(7, null)]);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.textContaining('Reason:'), findsNothing);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('works before the hire has even been started', (tester) async {
      final cancels = _Cancels();
      await _show(tester, _hire(), cancels);
      expect(find.text('PICKUP'), findsOneWidget);

      await _cancelWith(tester, reason: 'Vehicle will not start');

      expect(cancels.calls, [(7, 'Vehicle will not start')]);
      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('PICKUP'), findsNothing);
      expect(find.text('Hire Cancelled'), findsOneWidget);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('works on a paused hire', (tester) async {
      final cancels = _Cancels();
      await _show(tester, _hire(started: true, status: 'started'), cancels);

      await _cancelWith(tester);

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('START'), findsNothing);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('stops the tracking: the in-app timer no longer records positions', (tester) async {
      var recorded = 0;
      Future<TrackingStatus> record(int hireId) async {
        recorded++;
        return TrackingStatus(status: 'started', statusLabel: 'x', isTracking: true, totalDistanceKm: 1);
      }

      // control: a running hire records a position every 15 seconds
      await _show(tester, _hire(started: true, tracking: true, status: 'started'), _Cancels(), recordPoint: record);
      await tester.pump(const Duration(seconds: 16));
      await tester.pump();
      expect(recorded, 1);
      await tester.pump(const Duration(seconds: 15));
      expect(recorded, 2);
      await _hide(tester);

      // after cancelling, it records nothing more — however long we wait
      recorded = 0;
      await _show(tester, _hire(started: true, tracking: true, status: 'started'), _Cancels(), recordPoint: record);
      await _cancelWith(tester);
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();

      expect(recorded, 0);
      expect(find.text('CANCELLED'), findsOneWidget);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('stops watching for arrival', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(started: true, tracking: true, status: 'started'), _Cancels(), positions: positions);
      expect(positions.hasListener, isTrue);

      await _cancelWith(tester);

      expect(positions.hasListener, isFalse);

      await _hide(tester);
      unawaited(positions.close());
    }, variant: _iosOnly);

    testWidgets('the map stops planning a route once the hire is cancelled', (tester) async {
      await _show(tester, _hire(started: true, tracking: true, status: 'started'), _Cancels());
      expect(find.text('Route'), findsOneWidget); // the legend, while there is a way ahead

      await _cancelWith(tester);

      expect(find.text('Route'), findsNothing);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('a server refusal is shown, and the hire carries on', (tester) async {
      final cancels = _Cancels()..failWith = Exception('This hire has already been completed.');
      await _show(tester, _hire(started: true, tracking: true, status: 'started'), cancels);

      await _cancelWith(tester);

      expect(find.textContaining('already been completed'), findsOneWidget);
      expect(find.text('Complete Hire'), findsOneWidget); // still a live hire
      expect(find.text('CANCELLED'), findsNothing);
      expect(find.text('Hire Cancelled'), findsNothing);

      await _hide(tester);
    }, variant: _iosOnly);
  });

  group('a hire that is already cancelled', () {
    testWidgets('opens as cancelled: the notice, the reason, and no buttons', (tester) async {
      await _show(
        tester,
        _hire(status: 'cancelled', cancelledAt: DateTime(2026, 9, 24, 15, 40), cancelReason: 'Customer changed plans'),
        _Cancels(),
      );

      expect(find.text('CANCELLED'), findsOneWidget);
      expect(find.text('Hire Cancelled'), findsOneWidget);
      expect(find.textContaining('cancelled on Sep 24, 2026'), findsOneWidget);
      expect(find.text('Reason: Customer changed plans'), findsOneWidget);
      for (final gone in ['Cancel Hire', 'Complete Hire', 'START', 'PICKUP']) {
        expect(find.text(gone), findsNothing, reason: gone);
      }

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('watches no GPS and plans no route', (tester) async {
      final positions = StreamController<Position>.broadcast();
      await _show(tester, _hire(status: 'cancelled'), _Cancels(), positions: positions);

      expect(positions.hasListener, isFalse);
      expect(find.text('Route'), findsNothing);

      await _hide(tester);
      unawaited(positions.close());
    }, variant: _iosOnly);

    testWidgets('a cancelled hire that had been started never restarts tracking', (tester) async {
      var recorded = 0;
      await _show(
        tester,
        _hire(status: 'cancelled', started: true),
        _Cancels(),
        recordPoint: (id) async {
          recorded++;
          return _cancelledStatus();
        },
      );

      await tester.pump(const Duration(seconds: 60));

      expect(recorded, 0);

      await _hide(tester);
    }, variant: _iosOnly);
  });
}
