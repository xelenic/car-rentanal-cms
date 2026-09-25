import 'package:driver_app/models/hire.dart';
import 'package:driver_app/models/hire_map_targets.dart';
import 'package:driver_app/models/hire_stage.dart';
import 'package:flutter_test/flutter_test.dart';

Hire _hire({
  String tourType = 'drop_pickup',
  String? from = 'Colombo Fort',
  String? to = 'Ella',
  List<String> stays = const [],
  String? package,
  DateTime? trackingStartedAt,
}) =>
    Hire(
      id: 1,
      tourType: tourType,
      tourTypeLabel: tourType,
      fromLocation: from,
      toLocation: to,
      stayLocations: stays,
      package: package,
      hireFullValue: 100,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      trackingStartedAt: trackingStartedAt,
    );

List<String> _summary(List<MapTarget> targets) => targets.map((t) => '${t.label}: ${t.place}').toList();

void main() {
  group('mapTargetsOf', () {
    test('a drop-and-pickup hire has a separate pickup and end location', () {
      expect(_summary(mapTargetsOf(_hire())), ['Pickup location: Colombo Fort', 'End location: Ella']);
    });

    test('a day tour is treated the same way', () {
      expect(_summary(mapTargetsOf(_hire(tourType: 'day_tour', to: 'Kandy'))),
          ['Pickup location: Colombo Fort', 'End location: Kandy']);
    });

    test('only the places that exist are offered', () {
      expect(_summary(mapTargetsOf(_hire(to: null))), ['Pickup location: Colombo Fort']);
      expect(_summary(mapTargetsOf(_hire(from: '  ', to: 'Ella'))), ['End location: Ella']);
    });

    test('a multi day tour runs pickup → stops → end across its stays', () {
      final targets = mapTargetsOf(_hire(tourType: 'multi_day', from: null, to: null, stays: ['Kandy', 'Nuwara Eliya', 'Ella', 'Galle']));

      expect(_summary(targets), [
        'Pickup location: Kandy',
        'Stop 2: Nuwara Eliya',
        'Stop 3: Ella',
        'End location: Galle',
      ]);
    });

    test('a multi day tour with two stays has just a pickup and an end', () {
      expect(_summary(mapTargetsOf(_hire(tourType: 'multi_day', stays: ['Kandy', 'Galle']))),
          ['Pickup location: Kandy', 'End location: Galle']);
    });

    test('a single stay is just "Location"', () {
      expect(_summary(mapTargetsOf(_hire(tourType: 'multi_day', stays: ['Kandy']))), ['Location: Kandy']);
    });

    test('a package tour points at the package', () {
      expect(_summary(mapTargetsOf(_hire(tourType: 'package', from: null, to: null, package: 'Hill Country'))),
          ['Package location: Hill Country']);
    });

    test('a hire with nothing to show has no targets', () {
      expect(mapTargetsOf(_hire(from: null, to: null)), isEmpty);
    });
  });

  group('mapTargetFor', () {
    test('before the hire starts the driver heads for the pickup location', () {
      expect(mapTargetFor(_hire(), HireStage.pickup)?.place, 'Colombo Fort');
      expect(mapTargetFor(_hire(), HireStage.start)?.place, 'Colombo Fort');
    });

    test('once the hire is running it is the end location', () {
      expect(mapTargetFor(_hire(trackingStartedAt: DateTime(2026, 9, 24)), HireStage.inProgress)?.place, 'Ella');
    });

    test('a paused hire (already started once) also heads for the end location', () {
      expect(mapTargetFor(_hire(trackingStartedAt: DateTime(2026, 9, 24)), HireStage.start)?.place, 'Ella');
    });

    test('a completed hire has nowhere left to go', () {
      expect(mapTargetFor(_hire(), HireStage.completed), isNull);
    });

    test('multi day tours go from the first stay to the last', () {
      final hire = _hire(tourType: 'multi_day', stays: ['Kandy', 'Ella', 'Galle']);

      expect(mapTargetFor(hire, HireStage.pickup)?.place, 'Kandy');
      expect(mapTargetFor(hire, HireStage.inProgress)?.place, 'Galle');
    });

    test('a single place is the target at every stage', () {
      final package = _hire(tourType: 'package', from: null, to: null, package: 'Hill Country');

      expect(mapTargetFor(package, HireStage.pickup)?.place, 'Hill Country');
      expect(mapTargetFor(package, HireStage.inProgress)?.place, 'Hill Country');
    });

    test('no false target: with only a pickup place there is nothing to head for after starting', () {
      expect(mapTargetFor(_hire(to: null), HireStage.inProgress), isNull);
    });
  });

  group('mapRouteFor', () {
    test('before the hire starts the route runs Your location → pickup → end', () {
      final route = mapRouteFor(_hire(), HireStage.pickup)!;

      expect(route.waypoints, ['Colombo Fort']);
      expect(route.destination, 'Ella');
      expect(route.summary, 'You → Colombo Fort → Ella');
    });

    test('after picking up (before Start) it is still the whole route', () {
      expect(mapRouteFor(_hire(), HireStage.start)!.summary, 'You → Colombo Fort → Ella');
    });

    test('the link is a Google Maps directions link with the pickup as a waypoint and no origin', () {
      final url = mapRouteFor(_hire(), HireStage.pickup)!.url;

      expect(url.host, 'www.google.com');
      expect(url.path, '/maps/dir/');
      expect(url.queryParameters['api'], '1');
      expect(url.queryParameters['destination'], 'Ella');
      expect(url.queryParameters['waypoints'], 'Colombo Fort');
      expect(url.queryParameters['travelmode'], 'driving');
      expect(url.queryParameters.containsKey('origin'), isFalse); // → Maps starts from "Your location"
    });

    test('once the hire has started the customer is on board: Your location → end only', () {
      final started = _hire(trackingStartedAt: DateTime(2026, 9, 24));
      final route = mapRouteFor(started, HireStage.inProgress)!;

      expect(route.waypoints, isEmpty);
      expect(route.destination, 'Ella');
      expect(route.summary, 'You → Ella');
      expect(route.url.queryParameters.containsKey('waypoints'), isFalse);
    });

    test('a paused hire (already started once) also goes straight to the end', () {
      expect(mapRouteFor(_hire(trackingStartedAt: DateTime(2026, 9, 24)), HireStage.start)!.summary, 'You → Ella');
    });

    test('a multi day tour goes through every stop; after starting it skips the pickup', () {
      final hire = _hire(tourType: 'multi_day', from: null, to: null, stays: ['Kandy', 'Nuwara Eliya', 'Ella', 'Galle']);

      final before = mapRouteFor(hire, HireStage.pickup)!;
      expect(before.waypoints, ['Kandy', 'Nuwara Eliya', 'Ella']);
      expect(before.destination, 'Galle');
      expect(before.url.queryParameters['waypoints'], 'Kandy|Nuwara Eliya|Ella');

      final after = mapRouteFor(hire, HireStage.inProgress)!;
      expect(after.waypoints, ['Nuwara Eliya', 'Ella']);
      expect(after.destination, 'Galle');
    });

    test('place names are encoded, including non-latin ones', () {
      final route = mapRouteFor(_hire(from: 'Galle Face & Fort', to: 'ශ්‍රී ලංකා'), HireStage.pickup)!;

      expect(route.url.queryParameters['waypoints'], 'Galle Face & Fort');
      expect(route.url.queryParameters['destination'], 'ශ්‍රී ලංකා');
      expect(route.url.toString(), contains('waypoints=Galle%20Face%20%26%20Fort'));
    });

    test('a single place is just the destination', () {
      final route = mapRouteFor(_hire(tourType: 'package', from: null, to: null, package: 'Hill Country'), HireStage.pickup)!;

      expect(route.waypoints, isEmpty);
      expect(route.summary, 'You → Hill Country');
    });

    test('no end place: before starting it just goes to the pickup, after starting there is no route', () {
      expect(mapRouteFor(_hire(to: null), HireStage.pickup)!.summary, 'You → Colombo Fort');
      expect(mapRouteFor(_hire(to: null), HireStage.inProgress), isNull);
    });

    test('a completed hire or one with no places has no route', () {
      expect(mapRouteFor(_hire(), HireStage.completed), isNull);
      expect(mapRouteFor(_hire(from: null, to: null), HireStage.pickup), isNull);
    });

    test('never asks Google for more than its maximum number of intermediate stops', () {
      final hire = _hire(tourType: 'multi_day', from: null, to: null, stays: [for (var i = 1; i <= 15; i++) 'Stop $i']);

      expect(mapRouteFor(hire, HireStage.pickup)!.waypoints, hasLength(MapRoute.maxWaypoints));
    });
  });
}
