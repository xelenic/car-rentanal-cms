import 'dart:async';

import 'package:driver_app/models/hire.dart';
import 'package:driver_app/models/hire_map_point.dart';
import 'package:driver_app/models/map_role.dart';
import 'package:driver_app/models/tracking_status.dart';
import 'package:driver_app/screens/hire_detail_screen.dart';
import 'package:driver_app/services/pickup_store.dart';
import 'package:driver_app/widgets/hire_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'support/fake_google_maps.dart';

const _colombo = HireMapPoint(role: MapRole.pickup, name: 'Colombo Fort', latitude: 6.9344, longitude: 79.8428);
const _kandy = HireMapPoint(role: MapRole.stop, name: 'Kandy', latitude: 7.2906, longitude: 80.6337);
const _ella = HireMapPoint(role: MapRole.end, name: 'Ella', latitude: 6.8667, longitude: 81.0466);

class _NoPickupStore implements PickupStore {
  @override
  Future<bool> isPickedUp(int hireId) async => false;
  @override
  Future<void> markPickedUp(int hireId) async {}
  @override
  Future<void> clear(int hireId) async {}
}

Hire _hire({List<HireMapPoint> mapPoints = const []}) => Hire(
      id: 7,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Drop and Pickup',
      fromLocation: 'Colombo Fort',
      toLocation: 'Ella',
      mapPoints: mapPoints,
      hireFullValue: 95,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
    );

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

// Run as iOS so the Android-only background service isn't involved.
final _iosOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  group('markers', () {
    test('one per place, coloured by its part in the trip, with its name on tap', () {
      final markers = hireMarkers([_colombo, _kandy, _ella]).toList();

      expect(markers.map((m) => m.position), [
        const LatLng(6.9344, 79.8428),
        const LatLng(7.2906, 80.6337),
        const LatLng(6.8667, 81.0466),
      ]);
      expect(markers.map((m) => m.infoWindow.title), ['Pickup location', 'Stop', 'End location']);
      expect(markers.map((m) => m.infoWindow.snippet), ['Colombo Fort', 'Kandy', 'Ella']);
      expect(markers.map((m) => m.icon).toSet(), hasLength(3)); // green, orange, red
      expect(markers.map((m) => m.markerId.value).toSet(), hasLength(3)); // distinct ids
    });

    test('no places, no markers', () {
      expect(hireMarkers(const []), isEmpty);
    });

    test('the driver appears as a "You" marker once their position is known, centred on the spot', () {
      final markers = hireMarkers([_colombo], me: const LatLng(6.05, 80.22));
      final you = markers.singleWhere((m) => m.markerId.value == 'you');

      expect(markers, hasLength(2));
      expect(you.position, const LatLng(6.05, 80.22));
      expect(you.infoWindow.title, 'You');
      expect(you.anchor, const Offset(0.5, 0.5));
      expect(hireMarkers([_colombo]).where((m) => m.markerId.value == 'you'), isEmpty);
    });
  });

  group('driven path', () {
    List<TrackPoint> track(int n) => [for (var i = 0; i < n; i++) TrackPoint(lat: 6.9 + i / 10000, lng: 79.8)];

    test('needs at least two points to be a line', () {
      expect(hirePathLines(const []), isEmpty);
      expect(hirePathLines(track(1)), isEmpty);
      expect(hirePathLines(track(2)), hasLength(1));
    });

    test('a very long trip is thinned, keeping its first and last point', () {
      final path = track(5000);
      final thinned = thinPath(path);

      expect(thinned.length, lessThanOrEqualTo(400));
      expect(thinned.first, path.first);
      expect(thinned.last, path.last);
      expect(thinPath(track(50)), hasLength(50)); // short trips are left alone
    });
  });

  group('boundsOf', () {
    test('frames every point', () {
      final bounds = boundsOf(const [LatLng(6.9, 79.8), LatLng(7.3, 80.6), LatLng(6.8, 81.0)])!;

      expect(bounds.southwest, const LatLng(6.8, 79.8));
      expect(bounds.northeast, const LatLng(7.3, 81.0));
    });

    test('nothing, or a single spot, has nothing to frame', () {
      expect(boundsOf(const []), isNull);
      expect(boundsOf(const [LatLng(6.9, 79.8)]), isNull);
      expect(boundsOf(const [LatLng(6.9, 79.8), LatLng(6.9, 79.8)]), isNull);
    });
  });

  group('map_locations from the API', () {
    Map<String, dynamic> hireJson(Object? mapLocations) => {
          'id': 5,
          'tour_type': 'drop_pickup',
          'tour_type_label': 'Drop and Pickup',
          'hire_full_value': 100,
          'payment_type': 'cash',
          'payment_type_label': 'Cash',
          if (mapLocations != 'omit') 'map_locations': mapLocations,
        };

    test('are read in order', () {
      final hire = Hire.fromJson(hireJson([
        {'role': 'pickup', 'name': 'Colombo Fort', 'latitude': 6.9344, 'longitude': 79.8428},
        {'role': 'end', 'name': 'Ella', 'latitude': 6.8667, 'longitude': 81.0466},
      ]));

      expect(hire.mapPoints, [_colombo, _ella.copyRole(MapRole.end)]);
    });

    test('a server that does not send them, or sends nothing, gives an empty map', () {
      expect(Hire.fromJson(hireJson('omit')).mapPoints, isEmpty);
      expect(Hire.fromJson(hireJson(<Object>[])).mapPoints, isEmpty);
    });

    test('malformed or unknown entries are skipped, not fatal', () {
      final hire = Hire.fromJson(hireJson([
        {'role': 'teleporter', 'name': 'X', 'latitude': 1, 'longitude': 2},
        {'role': 'pickup', 'name': 'No coords'},
        'nonsense',
        {'role': 'pickup', 'name': 'Colombo Fort', 'latitude': 6.9344, 'longitude': 79.8428},
      ]));

      expect(hire.mapPoints, [_colombo]);
    });

    test('survive copyWith (the hire screen copies the hire on every status update)', () {
      final hire = _hire(mapPoints: [_colombo, _ella]);

      expect(hire.copyWith(isTracking: true).mapPoints, [_colombo, _ella]);
    });
  });

  group('the hire page map', () {
    late FakeGoogleMapsPlatform maps;
    setUp(() {
      maps = installFakeGoogleMaps();
      resetSharedMyLocation();
    });

    Future<void> show(WidgetTester tester, Hire hire) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: HireDetailScreen(hire: hire, pickupStore: _NoPickupStore())));
      await _settle(tester);
    }

    testWidgets('plots the hire\'s places, framed on the first one', (tester) async {
      await show(tester, _hire(mapPoints: [_colombo, _ella]));

      expect(find.byKey(const Key('fake-google-map')), findsOneWidget);
      expect(maps.markers.map((m) => m.infoWindow.snippet), ['Colombo Fort', 'Ella']);
      expect(maps.initialCamera!.target, const LatLng(6.9344, 79.8428));
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Full screen'), findsOneWidget);
      expect(find.text('Pickup'), findsOneWidget); // legend
      expect(find.text('End'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      expect(find.textContaining('no coordinates saved'), findsNothing);

      await tester.pumpWidget(const SizedBox());
    }, variant: _iosOnly);

    testWidgets('inline, the map lets the page scroll over it', (tester) async {
      await show(tester, _hire(mapPoints: [_colombo, _ella]));

      expect(maps.claimsGestures, isFalse);

      await tester.pumpWidget(const SizedBox());
    }, variant: _iosOnly);

    testWidgets('shows the driver as they move, and stops listening when the map goes away', (tester) async {
      final positions = StreamController<LatLng>.broadcast();
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HireMapView(places: const [_colombo, _ella], height: 300, locationOverride: positions.stream)),
      ));
      await _settle(tester);

      expect(maps.markers.where((m) => m.markerId.value == 'you'), isEmpty); // no fix yet
      expect(positions.hasListener, isTrue);

      positions.add(const LatLng(6.05, 80.22));
      await _settle(tester);
      expect(maps.markers.singleWhere((m) => m.markerId.value == 'you').position, const LatLng(6.05, 80.22));

      positions.add(const LatLng(6.58, 79.96)); // drives north
      await _settle(tester);
      expect(maps.markers.singleWhere((m) => m.markerId.value == 'you').position, const LatLng(6.58, 79.96));

      await tester.pumpWidget(const SizedBox());
      expect(positions.hasListener, isFalse);
      unawaited(positions.close());
    }, variant: _iosOnly);

    testWidgets('a map opened afterwards (the full screen one) shows the driver at once, without waiting for a fix', (tester) async {
      final positions = StreamController<LatLng>.broadcast();
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HireMapView(places: const [_colombo, _ella], height: 300, locationOverride: positions.stream)),
      ));
      await _settle(tester);
      positions.add(const LatLng(6.05, 80.22));
      await _settle(tester);

      // a second map, whose own position stream never speaks
      final silent = StreamController<LatLng>.broadcast();
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: HireMapView(places: const [_colombo, _ella], interactive: true, locationOverride: silent.stream)),
      ));
      await _settle(tester);

      expect(maps.markers.singleWhere((m) => m.markerId.value == 'you').position, const LatLng(6.05, 80.22));

      await tester.pumpWidget(const SizedBox());
      unawaited(positions.close());
      unawaited(silent.close());
    }, variant: _iosOnly);

    testWidgets('a hire whose places have no coordinates says so instead of showing an empty map', (tester) async {
      await show(tester, _hire());

      expect(maps.markers, isEmpty);
      expect(find.textContaining('no coordinates saved'), findsOneWidget);
      expect(maps.initialCamera!.target, kDefaultMapCenter);

      await tester.pumpWidget(const SizedBox());
    }, variant: _iosOnly);

    testWidgets('"Full screen" opens the map on its own screen, where it takes over the gestures', (tester) async {
      await show(tester, _hire(mapPoints: [_colombo, _kandy, _ella]));

      await tester.tap(find.text('Full screen'));
      await _settle(tester);

      expect(find.text('Hire #7 · Map'), findsOneWidget);
      expect(maps.claimsGestures, isTrue);
      expect(maps.markers, hasLength(3));
      // (the hire page underneath is still in the tree, so look only at this screen)
      expect(find.descendant(of: find.byType(HireMapScreen), matching: find.text('Stops')), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    }, variant: _iosOnly);

    testWidgets('opening a hire that was started draws its path straight away', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final started = Hire(
        id: 7,
        tourType: 'drop_pickup',
        tourTypeLabel: 'Drop and Pickup',
        mapPoints: const [_colombo, _ella],
        hireFullValue: 95,
        paymentType: 'cash',
        paymentTypeLabel: 'Cash',
        status: 'started',
        isTracking: true,
        trackingStartedAt: DateTime(2026, 9, 24, 8),
      );
      final asked = <int>[];

      await tester.pumpWidget(MaterialApp(
        home: HireDetailScreen(
          hire: started,
          pickupStore: _NoPickupStore(),
          loadTracking: (id) async {
            asked.add(id);
            return TrackingStatus(
              status: 'started',
              statusLabel: 'Driver Hire Started',
              isTracking: true,
              totalDistanceKm: 1.2,
              points: const [TrackPoint(lat: 6.93, lng: 79.84), TrackPoint(lat: 6.95, lng: 79.9), TrackPoint(lat: 6.97, lng: 79.95)],
            );
          },
        ),
      ));
      await _settle(tester);

      expect(asked, [7]);
      expect(maps.polylines.single.points, hasLength(3));
      expect(find.text('Driven path'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    }, variant: _iosOnly);

    testWidgets('a hire that was never started asks for no path, and a failing load just draws none', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var asked = 0;

      // never started → no request at all
      await tester.pumpWidget(MaterialApp(
        home: HireDetailScreen(
          hire: _hire(mapPoints: [_colombo, _ella]),
          pickupStore: _NoPickupStore(),
          loadTracking: (id) async {
            asked++;
            throw Exception('should not be called');
          },
        ),
      ));
      await _settle(tester);
      expect(asked, 0);
      await tester.pumpWidget(const SizedBox());

      // started, but the request fails (offline / older server) → the screen still works, no path
      await tester.pumpWidget(MaterialApp(
        home: HireDetailScreen(
          hire: Hire(
            id: 7,
            tourType: 'drop_pickup',
            tourTypeLabel: 'Drop and Pickup',
            mapPoints: const [_colombo, _ella],
            hireFullValue: 95,
            paymentType: 'cash',
            paymentTypeLabel: 'Cash',
            status: 'started',
            isTracking: true,
            trackingStartedAt: DateTime(2026, 9, 24, 8),
          ),
          pickupStore: _NoPickupStore(),
          loadTracking: (id) async => throw Exception('offline'),
        ),
      ));
      await _settle(tester);

      expect(tester.takeException(), isNull);
      expect(maps.polylines, isEmpty);
      expect(maps.markers, hasLength(2));

      await tester.pumpWidget(const SizedBox());
    }, variant: _iosOnly);

    testWidgets('the driven path is drawn once there are two points', (tester) async {
      tester.view.physicalSize = const Size(800, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: HireMapCard(
            hireId: 7,
            places: [_colombo, _ella],
            path: [TrackPoint(lat: 6.93, lng: 79.84), TrackPoint(lat: 6.95, lng: 79.9)],
          ),
        ),
      ));
      await _settle(tester);

      expect(maps.polylines, hasLength(1));
      expect(maps.polylines.single.points, hasLength(2));
      expect(find.text('Driven path'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    }, variant: _iosOnly);
  });
}

extension on HireMapPoint {
  HireMapPoint copyRole(MapRole role) => HireMapPoint(role: role, name: name, latitude: latitude, longitude: longitude);
}
