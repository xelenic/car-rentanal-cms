import 'package:driver_app/models/hire.dart';
import 'package:driver_app/screens/hire_detail_screen.dart';
import 'package:driver_app/services/pickup_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  String tourType = 'drop_pickup',
  String? from = 'Colombo Fort',
  String? to = 'Ella',
  List<String> stays = const [],
  String status = 'pending',
  bool isTracking = false,
  DateTime? trackingStartedAt,
}) =>
    Hire(
      id: 7,
      tourType: tourType,
      tourTypeLabel: tourType,
      fromLocation: from,
      toLocation: to,
      stayLocations: stays,
      hireFullValue: 95,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      status: status,
      isTracking: isTracking,
      trackingStartedAt: trackingStartedAt,
    );

/// Records every Maps link the screen tries to open.
class _Launches {
  final urls = <Uri>[];
  Future<bool> call(Uri url) async {
    urls.add(url);
    return true;
  }

  /// The place searched for by the n-th launch.
  String place(int n) => urls[n].queryParameters['query']!;
}

/// A tall screen so the tracking card and the Tour card are both on screen.
Future<void> _show(WidgetTester tester, Hire hire, _Launches launches, {bool pickedUp = false}) async {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: HireDetailScreen(
      hire: hire,
      pickupStore: _MemoryPickupStore(pickedUp ? [7] : []),
      launchMapsUrl: launches.call,
    ),
  ));
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Future<void> _hide(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
}

final _routeText = find.text('Open route in Google Maps');
final _pickupText = find.text('Open pickup location in Google Maps');
final _endText = find.text('Open end location in Google Maps');

// Run as iOS so the Android-only background service isn't involved.
final _iosOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  group('the action card opens the whole route', () {
    testWidgets('before the hire starts: Your location → pickup → end, in one Google Maps link', (tester) async {
      final launches = _Launches();
      await _show(tester, _hire(), launches);

      expect(_routeText, findsOneWidget);
      expect(find.text('You → Colombo Fort → Ella'), findsOneWidget);

      await tester.tap(_routeText);
      await tester.pump();

      expect(launches.urls, hasLength(1));
      final url = launches.urls.single;
      expect(url.host, 'www.google.com');
      expect(url.path, '/maps/dir/');
      expect(url.queryParameters['destination'], 'Ella'); // the drop-off is the end of the route…
      expect(url.queryParameters['waypoints'], 'Colombo Fort'); // …with the pickup on the way
      expect(url.queryParameters.containsKey('origin'), isFalse); // starts from Your location

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('after picking up (before Start) it is still the whole route', (tester) async {
      final launches = _Launches();
      await _show(tester, _hire(), launches, pickedUp: true);

      expect(find.text('You → Colombo Fort → Ella'), findsOneWidget);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('once the hire has started the customer is on board: Your location → end', (tester) async {
      final launches = _Launches();
      await _show(
        tester,
        _hire(status: 'started', isTracking: true, trackingStartedAt: DateTime(2026, 9, 24, 8)),
        launches,
      );

      expect(find.text('You → Ella'), findsOneWidget);

      await tester.tap(_routeText);
      await tester.pump();

      final url = launches.urls.single;
      expect(url.queryParameters['destination'], 'Ella');
      expect(url.queryParameters.containsKey('waypoints'), isFalse);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('a multi day tour routes through every stop', (tester) async {
      final launches = _Launches();
      await _show(
        tester,
        _hire(tourType: 'multi_day', from: null, to: null, stays: ['Kandy', 'Nuwara Eliya', 'Galle']),
        launches,
      );

      expect(find.text('You → Kandy → Nuwara Eliya → Galle'), findsOneWidget);

      await tester.tap(_routeText);
      await tester.pump();

      expect(launches.urls.single.queryParameters['waypoints'], 'Kandy|Nuwara Eliya');
      expect(launches.urls.single.queryParameters['destination'], 'Galle');

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('a completed hire has no route button', (tester) async {
      await _show(tester, _hire(status: 'completed'), _Launches());

      expect(_routeText, findsNothing);

      await _hide(tester);
    }, variant: _iosOnly);
  });

  group('the Tour card keeps each place as its own button', () {
    testWidgets('pickup and end are separate, and each opens just its own place', (tester) async {
      final launches = _Launches();
      await _show(tester, _hire(), launches);

      expect(_pickupText, findsOneWidget);
      expect(_endText, findsOneWidget);

      await tester.tap(_pickupText);
      await tester.pump();
      await tester.tap(_endText);
      await tester.pump();

      expect(launches.place(0), 'Colombo Fort');
      expect(launches.place(1), 'Ella');

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('they stay available after the hire is completed', (tester) async {
      await _show(tester, _hire(status: 'completed'), _Launches());

      expect(_pickupText, findsOneWidget);
      expect(_endText, findsOneWidget);

      await _hide(tester);
    }, variant: _iosOnly);

    testWidgets('a multi day tour gets a button per stop', (tester) async {
      final launches = _Launches();
      await _show(
        tester,
        _hire(tourType: 'multi_day', from: null, to: null, stays: ['Kandy', 'Nuwara Eliya', 'Galle']),
        launches,
      );

      expect(_pickupText, findsOneWidget);
      expect(find.text('Open stop 2 in Google Maps'), findsOneWidget);
      expect(_endText, findsOneWidget);

      await tester.tap(find.text('Open stop 2 in Google Maps'));
      await tester.pump();
      expect(launches.place(0), 'Nuwara Eliya');

      await _hide(tester);
    }, variant: _iosOnly);
  });

  testWidgets('a hire with no locations shows no Maps buttons at all', (tester) async {
    await _show(tester, _hire(from: null, to: null), _Launches());

    expect(find.textContaining('in Google Maps'), findsNothing);

    await _hide(tester);
  }, variant: _iosOnly);
}
