import 'package:driver_app/models/hire.dart';
import 'package:driver_app/models/hire_stage.dart';
import 'package:driver_app/services/arrival_detector.dart';
import 'package:flutter_test/flutter_test.dart';

Hire _hire({
  String status = 'pending',
  bool isTracking = false,
  DateTime? trackingStartedAt,
}) =>
    Hire(
      id: 1,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Drop and Pickup',
      hireFullValue: 100,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      status: status,
      isTracking: isTracking,
      trackingStartedAt: trackingStartedAt,
    );

void main() {
  group('hireStageOf', () {
    test('a fresh hire offers Pickup', () {
      expect(hireStageOf(_hire(), pickedUp: false), HireStage.pickup);
    });

    test('once picked up it offers Start', () {
      expect(hireStageOf(_hire(), pickedUp: true), HireStage.start);
    });

    test('a running hire offers Stop and Complete, whatever the pickup mark says', () {
      final running = _hire(status: 'started', isTracking: true, trackingStartedAt: DateTime(2026, 9, 24));

      expect(hireStageOf(running, pickedUp: false), HireStage.inProgress);
      expect(hireStageOf(running, pickedUp: true), HireStage.inProgress);
    });

    test('a hire stopped after being started goes back to Start, never to Pickup', () {
      final paused = _hire(status: 'started', trackingStartedAt: DateTime(2026, 9, 24));

      expect(hireStageOf(paused, pickedUp: false), HireStage.start);
    });

    test('a completed hire is completed', () {
      expect(hireStageOf(_hire(status: 'completed'), pickedUp: true), HireStage.completed);
    });
  });

  group('distanceMeters', () {
    test('is zero for the same point', () {
      expect(distanceMeters(6.9344, 79.8428, 6.9344, 79.8428), closeTo(0, 0.001));
    });

    test('matches a known distance (Colombo Fort to Kandy is about 94 km in a straight line)', () {
      expect(distanceMeters(6.9344, 79.8428, 7.2906, 80.6337) / 1000, closeTo(94, 3));
    });

    test('one hundredth of a degree of latitude is about 1.1 km', () {
      expect(distanceMeters(6.90, 79.85, 6.91, 79.85), closeTo(1112, 5));
    });
  });

  group('ArrivalDetector', () {
    test('arrives inside the enter radius and not before', () {
      final detector = ArrivalDetector(enterRadiusMeters: 250, exitRadiusMeters: 350);

      expect(detector.update(900), isFalse);
      expect(detector.arrived, isFalse);

      expect(detector.update(240), isTrue); // changed → arrived
      expect(detector.arrived, isTrue);
    });

    test('does not flicker at the edge: it stays arrived until clearly outside the exit radius', () {
      final detector = ArrivalDetector(enterRadiusMeters: 250, exitRadiusMeters: 350);
      detector.update(100);

      expect(detector.update(300), isFalse); // outside 250 but inside 350 → still there
      expect(detector.arrived, isTrue);

      expect(detector.update(360), isTrue); // clearly gone
      expect(detector.arrived, isFalse);
    });

    test('needs to come back inside the enter radius (not just the exit radius) to arrive again', () {
      final detector = ArrivalDetector(enterRadiusMeters: 250, exitRadiusMeters: 350);
      detector.update(100);
      detector.update(400);

      detector.update(300);
      expect(detector.arrived, isFalse);

      detector.update(200);
      expect(detector.arrived, isTrue);
    });

    test('reset forgets the arrival', () {
      final detector = ArrivalDetector()..update(10);
      detector.reset();

      expect(detector.arrived, isFalse);
    });
  });

  group('Hire pickup location', () {
    Map<String, dynamic> json({Object? pickup = 'omit'}) => {
          'id': 5,
          'tour_type': 'drop_pickup',
          'tour_type_label': 'Drop and Pickup',
          'hire_full_value': 100,
          'payment_type': 'cash',
          'payment_type_label': 'Cash',
          if (pickup != 'omit') 'pickup_location': pickup,
        };

    test('is read from the API', () {
      final hire = Hire.fromJson(json(pickup: {'name': 'Colombo Fort', 'latitude': 6.9344, 'longitude': 79.8428}));

      expect(hire.pickupLocationName, 'Colombo Fort');
      expect(hire.pickupLatitude, 6.9344);
      expect(hire.pickupLongitude, 79.8428);
      expect(hire.hasPickupCoordinates, isTrue);
    });

    test('an older server that does not send it, or sends null, just means no arrival highlight', () {
      expect(Hire.fromJson(json()).hasPickupCoordinates, isFalse);
      expect(Hire.fromJson(json(pickup: null)).hasPickupCoordinates, isFalse);
    });

    test('survives copyWith (the hire screen copies the hire on every status update)', () {
      final hire = Hire.fromJson(json(pickup: {'name': 'Colombo Fort', 'latitude': 6.9344, 'longitude': 79.8428}));

      final copy = hire.copyWith(isTracking: true);

      expect(copy.pickupLocationName, 'Colombo Fort');
      expect(copy.pickupLatitude, 6.9344);
      expect(copy.hasPickupCoordinates, isTrue);
    });
  });
}
