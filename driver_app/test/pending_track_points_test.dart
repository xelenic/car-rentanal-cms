import 'package:driver_app/models/tracking_status.dart';
import 'package:driver_app/services/pending_track_points.dart';
import 'package:flutter_test/flutter_test.dart';

PendingTrackPoint _point(int hireId, int n, {DateTime? at}) => PendingTrackPoint(
      hireId: hireId,
      latitude: 10.0 + n,
      longitude: 79.8,
      capturedAt: at ?? DateTime.utc(2026, 9, 24, 10, 0, n),
    );

TrackingStatus _status({bool tracking = true, double km = 1}) => TrackingStatus(
      status: 'started',
      statusLabel: 'Driver Hire Started',
      isTracking: tracking,
      totalDistanceKm: km,
    );

void main() {
  group('flushHire', () {
    test('sends a hire\'s points oldest first and empties the queue', () async {
      final queue = PendingTrackPoints([_point(33, 1), _point(21, 2), _point(33, 3)]);
      final sent = <double>[];

      final status = await queue.flushHire(33, (p) async {
        sent.add(p.latitude);
        return _status(km: sent.length.toDouble());
      });

      expect(sent, [11.0, 13.0]);
      expect(status?.totalDistanceKm, 2); // the status of the last accepted point
      expect(queue.countForHire(33), 0);
      expect(queue.countForHire(21), 1); // other hires are untouched
    });

    test('keeps the points that were not accepted, in order, when a send fails', () async {
      final queue = PendingTrackPoints([_point(33, 1), _point(33, 2), _point(33, 3)]);
      var calls = 0;

      await expectLater(
        queue.flushHire(33, (p) async {
          if (++calls == 2) throw Exception('offline');
          return _status();
        }),
        throwsException,
      );

      // #1 was accepted; #2 (the one that failed) and #3 are still waiting.
      expect(queue.length, 2);
      final resent = <double>[];
      await queue.flushHire(33, (p) async {
        resent.add(p.latitude);
        return _status();
      });
      expect(resent, [12.0, 13.0]);
    });

    test('sends at most `limit` points per call so one tick cannot run away', () async {
      final queue = PendingTrackPoints([for (var i = 0; i < 25; i++) _point(33, i)]);

      await queue.flushHire(33, (_) async => _status(), limit: 10);

      expect(queue.length, 15);
    });

    test('returns null when nothing is queued for the hire', () async {
      final queue = PendingTrackPoints([_point(21, 1)]);

      expect(await queue.flushHire(33, (_) async => _status()), isNull);
    });
  });

  group('recordedAtFor', () {
    final captured = DateTime.utc(2026, 9, 24, 10, 0, 0);

    test('lets the server stamp a fresh fix', () {
      expect(_point(33, 0, at: captured).recordedAtFor(captured.add(const Duration(seconds: 20))), isNull);
    });

    test('reports the original time of a fix that waited in the queue', () {
      expect(
        _point(33, 0, at: captured).recordedAtFor(captured.add(const Duration(minutes: 6))),
        captured,
      );
    });
  });

  group('queue housekeeping', () {
    test('retainHires drops points of hires that are no longer tracked', () {
      final queue = PendingTrackPoints([_point(33, 1), _point(21, 2), _point(10, 3)]);

      queue.retainHires({33});

      expect(queue.length, 1);
      expect(queue.countForHire(33), 1);
    });

    test('is capped at maxPoints, dropping the oldest', () {
      final queue = PendingTrackPoints();
      for (var i = 0; i < PendingTrackPoints.maxPoints + 20; i++) {
        queue.add(_point(33, i));
      }

      expect(queue.length, PendingTrackPoints.maxPoints);
    });

    test('survives an encode/decode round trip', () {
      final queue = PendingTrackPoints([_point(33, 1), _point(21, 2)]);

      final restored = PendingTrackPoints.decode(queue.encode());

      expect(restored.length, 2);
      expect(restored.countForHire(33), 1);
      expect(restored.countForHire(21), 1);
    });

    test('decoding nothing or garbage gives an empty queue instead of throwing', () {
      expect(PendingTrackPoints.decode(null).isEmpty, isTrue);
      expect(PendingTrackPoints.decode('').isEmpty, isTrue);
      expect(PendingTrackPoints.decode('{not json').isEmpty, isTrue);
      expect(PendingTrackPoints.decode('{"a":1}').isEmpty, isTrue);
      // one bad entry doesn't take the good ones down with it
      expect(
        PendingTrackPoints.decode('[{"h":1,"lat":6.9,"lng":79.8,"at":"2026-09-24T10:00:00Z"},{"h":"x"}]').length,
        1,
      );
    });

    test('an empty queue encodes to an empty string', () {
      expect(PendingTrackPoints().encode(), '');
    });
  });
}
