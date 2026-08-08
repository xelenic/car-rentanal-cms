import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:driver_app/models/hire.dart';
import 'package:driver_app/screens/hire_detail_screen.dart';

void main() {
  testWidgets('HireDetailScreen renders normally for a completed hire', (
    WidgetTester tester,
  ) async {
    final hire = Hire(
      id: 7,
      tourType: 'drop_pickup',
      tourTypeLabel: 'Drop and Pickup',
      fromLocation: 'Matara',
      toLocation: 'Matara',
      hireFullValue: 95.0,
      paymentType: 'cash',
      paymentTypeLabel: 'Cash',
      description: 'Demo hire so the app has something to show.',
      vehicle: 'Hiace',
      status: 'completed',
      statusLabel: 'Completed',
      isTracking: false,
      totalDistanceKm: 153.9,
    );

    await tester.pumpWidget(MaterialApp(home: HireDetailScreen(hire: hire)));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hire Completed'), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('Vehicle & Payment'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tour'), findsOneWidget);
    expect(find.text('Vehicle & Payment'), findsOneWidget);
  });
}
