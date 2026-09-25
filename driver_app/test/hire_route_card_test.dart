import 'package:driver_app/models/hire.dart';
import 'package:driver_app/screens/hire_detail_screen.dart';
import 'package:driver_app/widgets/hire_route_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_google_maps.dart';

Hire _hire({String status = 'pending', DateTime? startTime, DateTime? cancelledAt}) => Hire(
      id: 7,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Drop and Pickup',
      fromLocation: 'Colombo Fort',
      toLocation: 'Ella',
      hireFullValue: 100,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      status: status,
      startTime: startTime,
      cancelledAt: cancelledAt,
    );

Widget _app(Widget card) => MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: card)));

/// The hire screen never stops animating (its button breathes), so settle by
/// pumping a few frames rather than waiting for everything to stop.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

// Run as iOS so the Android-only background service isn't involved.
final _iosOnly = TargetPlatformVariant.only(TargetPlatform.iOS);

void main() {
  setUp(installFakeGoogleMaps);

  testWidgets('tapping a card opens the hire, and coming back reports it so the list can refresh', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var returned = 0;

    await tester.pumpWidget(_app(HireRouteCard(hire: _hire(), onReturn: () => returned++)));
    await tester.tap(find.byType(HireRouteCard));
    await _settle(tester);

    expect(find.byType(HireDetailScreen), findsOneWidget);
    expect(returned, 0); // still looking at the hire

    await tester.pageBack();
    await _settle(tester);

    expect(find.byType(HireDetailScreen), findsNothing);
    expect(returned, 1);
  }, variant: _iosOnly);

  testWidgets('a card works without a callback (as on screens that do not refresh)', (tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(HireRouteCard(hire: _hire())));
    await tester.tap(find.byType(HireRouteCard));
    await _settle(tester);
    await tester.pageBack();
    await _settle(tester);

    expect(tester.takeException(), isNull);
  }, variant: _iosOnly);

  group('the line under the route', () {
    testWidgets('an open hire with a schedule shows when', (tester) async {
      await tester.pumpWidget(_app(HireRouteCard(hire: _hire(startTime: DateTime(2026, 9, 27, 14, 30)))));

      expect(find.text('Scheduled Sep 27, 2:30 PM'), findsOneWidget);
    });

    testWidgets('a cancelled hire shows when it was cancelled, in red', (tester) async {
      await tester.pumpWidget(_app(HireRouteCard(hire: _hire(status: 'cancelled', cancelledAt: DateTime(2026, 9, 24, 15, 40)))));

      final text = tester.widget<Text>(find.text('Cancelled Sep 24, 3:40 PM'));
      expect(text.style!.color, isNot(equals(const TextStyle().color)));
    });

    testWidgets('a completed hire, or one with no schedule, has no extra line', (tester) async {
      await tester.pumpWidget(_app(HireRouteCard(hire: _hire(status: 'completed', startTime: DateTime(2026, 9, 20)))));
      expect(find.textContaining('Scheduled'), findsNothing);

      await tester.pumpWidget(_app(HireRouteCard(hire: _hire())));
      expect(find.textContaining('Scheduled'), findsNothing);
    });
  });
}
