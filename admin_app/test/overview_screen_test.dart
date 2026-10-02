import 'package:admin_app/screens/overview_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

Future<void> _show(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: const OverviewScreen()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the six summary cards in order, for the current month by default', (tester) async {
    final server = FakeServer(
      dashboard: defaultDashboardJson(year: 2026, month: 9)
        ..['summary'] = {
          'hire_full_value_total': 10000,
          'our_hire_value_total': 7000,
          'commission_total': 3000,
          'expenses_total': 500,
          'salary_total': 1300,
          'profit_total': 5200,
        },
    );
    await _show(tester, server);

    final labels = ['Total Hire Value', 'Our Hire Value', 'Total Commission', 'Total Expenses', 'All Drivers Salary', 'Total Profit'];
    for (final label in labels) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Rs. 10000.00'), findsOneWidget);
    expect(find.text('Rs. 5200.00'), findsOneWidget);

    // Defaults to today's year/month — both sent on the very first request,
    // without the test having to know what "today" actually is.
    final firstRequest = server.requestsTo('/api/admin/dashboard').first;
    final now = DateTime.now();
    expect(firstRequest.url.queryParameters['year'], '${now.year}');
    expect(firstRequest.url.queryParameters['month'], '${now.month}');
  });

  testWidgets('switching the month reloads the dashboard for that period', (tester) async {
    final server = FakeServer(dashboard: defaultDashboardJson());
    await _show(tester, server);

    // The two PeriodDropdowns: year first, month second.
    await tester.tap(find.byType(DropdownButton<int>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('July').last);
    await tester.pumpAndSettle();

    final requests = server.requestsTo('/api/admin/dashboard');
    expect(requests.last.url.queryParameters['month'], '7');
  });

  testWidgets('shows a Vehicle Cards section with one card per vehicle', (tester) async {
    final server = FakeServer(
      dashboard: defaultDashboardJson(vehicleCards: [
        dashboardVehicleCardJson(id: 1, model: 'ZZZ Prius', full: 10000, our: 7000),
        dashboardVehicleCardJson(id: 2, model: 'ZZZ Axio', full: 4000, our: 3000),
      ]),
    );
    await _show(tester, server);

    expect(find.text('Vehicle Cards'), findsOneWidget);
    expect(find.text('ZZZ Prius'), findsOneWidget);
    expect(find.text('ZZZ Axio'), findsOneWidget);
  });

  testWidgets('shows nothing extra when there are no vehicles', (tester) async {
    await _show(tester, FakeServer(dashboard: defaultDashboardJson()));

    expect(find.text('Vehicle Cards'), findsNothing);
  });

  testWidgets('shows a retry option when the dashboard fails to load', (tester) async {
    final server = FakeServer()..failWith = 500;
    await _show(tester, server);

    expect(find.text('Retry'), findsOneWidget);
  });
}
