import 'package:driver_app/models/hire.dart';
import 'package:driver_app/models/hire_map_point.dart';
import 'package:driver_app/models/hire_stage.dart';
import 'package:driver_app/models/map_role.dart';
import 'package:driver_app/models/tracking_status.dart';
import 'package:driver_app/services/arrival_target.dart';
import 'package:flutter_test/flutter_test.dart';

const _pickup = HireMapPoint(role: MapRole.pickup, name: 'Colombo Fort', latitude: 6.9344, longitude: 79.8428);
const _stop = HireMapPoint(role: MapRole.stop, name: 'Kandy', latitude: 7.2906, longitude: 80.6337);
const _stop2 = HireMapPoint(role: MapRole.stop, name: 'Nuwara Eliya', latitude: 6.9497, longitude: 80.7891);
const _end = HireMapPoint(role: MapRole.end, name: 'Ella', latitude: 6.8667, longitude: 81.0466);

Hire _hire({
  List<HireMapPoint> places = const [_pickup, _end],
  bool started = false,
  bool pickupCoordinates = true,
}) =>
    Hire(
      id: 1,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Drop and Pickup',
      hireFullValue: 100,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      pickupLocationName: pickupCoordinates ? 'Colombo Fort' : null,
      pickupLatitude: pickupCoordinates ? 6.9344 : null,
      pickupLongitude: pickupCoordinates ? 79.8428 : null,
      mapPoints: places,
      status: started ? 'started' : 'pending',
      trackingStartedAt: started ? DateTime(2026, 9, 25, 8) : null,
    );

void main() {
  group('arrivalTargetFor', () {
    test('once picked up and not yet started, it is the pickup location (the Start button)', () {
      final target = arrivalTargetFor(_hire(), stage: HireStage.start)!;

      expect(target.goal, ArrivalGoal.pickup);
      expect(target.name, 'Colombo Fort');
      expect(target.latitude, 6.9344);
    });

    test('before Pickup is pressed there is nothing to watch for', () {
      expect(arrivalTargetFor(_hire(), stage: HireStage.pickup), isNull);
    });

    test('no saved pickup coordinates, no pickup arrival', () {
      expect(arrivalTargetFor(_hire(pickupCoordinates: false), stage: HireStage.start), isNull);
    });

    test('once the hire is running it is the end location (the Complete button)', () {
      final target = arrivalTargetFor(_hire(started: true), stage: HireStage.inProgress)!;

      expect(target.goal, ArrivalGoal.end);
      expect(target.name, 'Ella');
      expect(target.longitude, 81.0466);
    });

    test('a paused hire (stopped after starting) still heads for the end', () {
      expect(arrivalTargetFor(_hire(started: true), stage: HireStage.start)!.goal, ArrivalGoal.end);
    });

    test('a multi day tour watches its first stop before heading to the end', () {
      final hire = _hire(places: const [_pickup, _stop, _end], started: true);

      final target = arrivalTargetFor(hire, stage: HireStage.inProgress)!;
      expect(target.goal, ArrivalGoal.stop);
      expect(target.name, 'Kandy');
    });

    test('once the recorded path shows the first stop was reached and left, the watch moves to the end', () {
      final hire = _hire(places: const [_pickup, _stop, _end], started: true);
      const path = [
        TrackPoint(lat: 6.9344, lng: 79.8428), // at the pickup
        TrackPoint(lat: 7.2906, lng: 80.6337), // reached Kandy
        TrackPoint(lat: 6.90, lng: 80.90), // well clear of it again
      ];

      final target = arrivalTargetFor(hire, stage: HireStage.inProgress, path: path)!;
      expect(target.goal, ArrivalGoal.end);
      expect(target.name, 'Ella');
    });

    test('driving toward the first stop — still far from it — does not skip to the second', () {
      final hire = _hire(places: const [_pickup, _stop, _stop2, _end], started: true);
      // On the way from the pickup, nowhere near either stop yet.
      const path = [TrackPoint(lat: 7.0, lng: 80.0), TrackPoint(lat: 7.1, lng: 80.2)];

      final target = arrivalTargetFor(hire, stage: HireStage.inProgress, path: path)!;
      expect(target.name, 'Kandy');
    });

    test('each stop on a multi-stop tour gets its own turn, in order', () {
      final hire = _hire(places: const [_pickup, _stop, _stop2, _end], started: true);

      expect(arrivalTargetFor(hire, stage: HireStage.inProgress)!.name, 'Kandy');

      const pastFirstStop = [
        TrackPoint(lat: 7.2906, lng: 80.6337),
        TrackPoint(lat: 6.90, lng: 80.90),
      ];
      expect(arrivalTargetFor(hire, stage: HireStage.inProgress, path: pastFirstStop)!.name, 'Nuwara Eliya');

      const pastBothStops = [
        TrackPoint(lat: 7.2906, lng: 80.6337),
        TrackPoint(lat: 6.90, lng: 80.90),
        TrackPoint(lat: 6.9497, lng: 80.7891),
        TrackPoint(lat: 6.80, lng: 81.10),
      ];
      expect(arrivalTargetFor(hire, stage: HireStage.inProgress, path: pastBothStops)!.name, 'Ella');
    });

    test('a hire with no end location with coordinates has nothing to watch for after starting', () {
      expect(arrivalTargetFor(_hire(places: const [_pickup], started: true), stage: HireStage.inProgress), isNull);
    });

    test('a lone place has no separate end, so nothing lights up', () {
      const only = HireMapPoint(role: MapRole.single, name: 'Hill Country', latitude: 7, longitude: 80);

      expect(arrivalTargetFor(_hire(places: const [only], started: true), stage: HireStage.inProgress), isNull);
    });

    test('a completed hire has nothing to watch for', () {
      expect(arrivalTargetFor(_hire(started: true), stage: HireStage.completed), isNull);
    });
  });

  group('endIsWhereItStarted', () {
    const sameSpot = HireMapPoint(role: MapRole.end, name: 'Colombo Fort', latitude: 6.9346, longitude: 79.8430);

    test('is true for a round trip', () {
      expect(endIsWhereItStarted(_hire(places: const [_pickup, sameSpot])), isTrue);
    });

    test('is false when the trip ends somewhere else', () {
      expect(endIsWhereItStarted(_hire()), isFalse);
    });

    test('is false when either end is missing', () {
      expect(endIsWhereItStarted(_hire(places: const [_pickup])), isFalse);
      expect(endIsWhereItStarted(_hire(places: const [_end])), isFalse);
    });
  });

  group('pathHasLeft', () {
    const target = ArrivalTarget(goal: ArrivalGoal.end, name: 'Colombo Fort', latitude: 6.9344, longitude: 79.8428);

    test('is false while every recorded point is still at the place', () {
      expect(pathHasLeft(const [TrackPoint(lat: 6.9344, lng: 79.8428), TrackPoint(lat: 6.9346, lng: 79.8430)], target), isFalse);
      expect(pathHasLeft(const [], target), isFalse);
    });

    test('is true once any point has been well clear of it', () {
      expect(pathHasLeft(const [TrackPoint(lat: 6.9344, lng: 79.8428), TrackPoint(lat: 7.10, lng: 80.0)], target), isTrue);
    });

    test('a point just outside the arrival circle but inside the exit circle does not count as having left', () {
      // ~300 m north: past the 250 m arrival radius, inside the 350 m exit radius
      expect(pathHasLeft(const [TrackPoint(lat: 6.9344 + 0.0027, lng: 79.8428)], target), isFalse);
    });
  });

  group('pathHasVisitedAndLeft', () {
    const target = ArrivalTarget(goal: ArrivalGoal.stop, name: 'Kandy', latitude: 7.2906, longitude: 80.6337);

    test('is false for an empty path', () {
      expect(pathHasVisitedAndLeft(const [], target), isFalse);
    });

    test('is false when the path never came near it — still on the way, not skipped past', () {
      expect(pathHasVisitedAndLeft(const [TrackPoint(lat: 6.0, lng: 80.0), TrackPoint(lat: 6.5, lng: 80.3)], target), isFalse);
    });

    test('is false while the path is still at the place', () {
      expect(pathHasVisitedAndLeft(const [TrackPoint(lat: 7.2906, lng: 80.6337)], target), isFalse);
    });

    test('is true once the path reached it and then moved well clear', () {
      expect(
        pathHasVisitedAndLeft(const [
          TrackPoint(lat: 6.0, lng: 80.0), // on the way, far from it
          TrackPoint(lat: 7.2906, lng: 80.6337), // reached it
          TrackPoint(lat: 6.90, lng: 80.90), // moved well clear
        ], target),
        isTrue,
      );
    });

    test('moving far away before ever reaching it is not a visit', () {
      // Passes nowhere near Kandy, ends up well past the exit radius anyway.
      expect(pathHasVisitedAndLeft(const [TrackPoint(lat: 6.0, lng: 80.0), TrackPoint(lat: 6.90, lng: 80.90)], target), isFalse);
    });
  });
}
