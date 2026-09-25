import 'package:driver_app/models/hire_map_point.dart';
import 'package:driver_app/models/map_role.dart';
import 'package:driver_app/services/route_planner.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

const _pickup = HireMapPoint(role: MapRole.pickup, name: 'Colombo Fort', latitude: 6.9344, longitude: 79.8428);
const _stop = HireMapPoint(role: MapRole.stop, name: 'Kandy', latitude: 7.2906, longitude: 80.6337);
const _end = HireMapPoint(role: MapRole.end, name: 'Ella', latitude: 6.8667, longitude: 81.0466);

void main() {
  group('decodePolyline', () {
    test('decodes the example from Google\'s documentation', () {
      // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
      final points = decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

      expect(points, [
        const LatLng(38.5, -120.2),
        const LatLng(40.7, -120.95),
        const LatLng(43.252, -126.453),
      ]);
    });

    test('an empty string is no points', () {
      expect(decodePolyline(''), isEmpty);
    });
  });

  group('formatting', () {
    test('distances', () {
      expect(formatRouteDistance(850), '850 m');
      expect(formatRouteDistance(1000), '1.0 km');
      expect(formatRouteDistance(12345), '12.3 km');
      expect(formatRouteDistance(94000), '94.0 km');
      expect(formatRouteDistance(257400), '257 km');
    });

    test('durations', () {
      expect(formatRouteDuration(20), '1 min');
      expect(formatRouteDuration(900), '15 min');
      expect(formatRouteDuration(3600), '1 h');
      expect(formatRouteDuration(5520), '1 h 32 min');
    });
  });

  group('PlannedRoute', () {
    test('is read from the API response, with a summary', () {
      final route = PlannedRoute.fromJson({'polyline': '_p~iF~ps|U_ulLnnqC', 'distance_m': 94000, 'duration_s': 7200});

      expect(route.points, hasLength(2));
      expect(route.approximate, isFalse);
      expect(route.summary, '94.0 km · 2 h');
    });

    test('a straight line has no summary', () {
      expect(straightRoute(const LatLng(6.05, 80.22), [_end]).summary, isNull);
    });
  });

  group('routeStopsFor', () {
    test('before the hire starts everything is still ahead', () {
      expect(routeStopsFor([_pickup, _end], started: false), [_pickup, _end]);
    });

    test('once started the pickup is behind the driver', () {
      expect(routeStopsFor([_pickup, _stop, _end], started: true), [_stop, _end]);
      expect(routeStopsFor([_pickup, _end], started: true), [_end]);
    });

    test('a lone place is ahead the whole way', () {
      const only = HireMapPoint(role: MapRole.single, name: 'Hill Country', latitude: 7, longitude: 80);

      expect(routeStopsFor([only], started: true), [only]);
      expect(routeStopsFor([only], started: false), [only]);
    });

    test('a finished hire has nothing ahead', () {
      expect(routeStopsFor([_pickup, _end], started: true, completed: true), isEmpty);
    });
  });

  test('straightRoute goes from the driver through every stop, flagged as approximate', () {
    final route = straightRoute(const LatLng(6.05, 80.22), [_stop, _end]);

    expect(route.approximate, isTrue);
    expect(route.points, [const LatLng(6.05, 80.22), const LatLng(7.2906, 80.6337), const LatLng(6.8667, 81.0466)]);
  });
}
