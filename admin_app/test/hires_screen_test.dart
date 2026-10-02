import 'package:admin_app/screens/hire_detail_screen.dart';
import 'package:admin_app/screens/hire_form_screen.dart';
import 'package:admin_app/screens/hires_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

Future<void> _show(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(412, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(
    MaterialApp(theme: buildAdminAppTheme(), home: HiresScreen(user: server.adminUser)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists every hire via HireCard', (tester) async {
    await _show(
      tester,
      FakeServer(allHires: [
        hireJson(id: 1, customer: 'ZZZ First Customer'),
        hireJson(id: 2, customer: 'ZZZ Second Customer'),
      ]),
    );

    expect(find.text('ZZZ First Customer'), findsOneWidget);
    expect(find.text('ZZZ Second Customer'), findsOneWidget);
  });

  testWidgets('shows an empty state with no hires yet', (tester) async {
    await _show(tester, FakeServer());

    expect(find.text('No hires yet'), findsOneWidget);
  });

  testWidgets('search narrows the list and asks the server for it', (tester) async {
    final server = FakeServer(allHires: [hireJson(id: 1, customer: 'ZZZ Searchable')]);
    await _show(tester, server);

    await tester.enterText(find.byKey(const Key('hire-search')), 'ZZZ Searchable');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final requests = server.requestsTo('/api/admin/hires');
    expect(requests.last.url.queryParameters['search'], 'ZZZ Searchable');
  });

  testWidgets('the Upcoming filter chip asks the server for upcoming only', (tester) async {
    final server = FakeServer(allHires: [hireJson(id: 1)]);
    await _show(tester, server);

    await tester.tap(find.byKey(const Key('upcoming-only')));
    await tester.pumpAndSettle();

    final requests = server.requestsTo('/api/admin/hires');
    expect(requests.last.url.queryParameters['upcoming'], '1');
  });

  testWidgets('tapping a hire opens its detail screen', (tester) async {
    await _show(tester, FakeServer(allHires: [hireJson(id: 7, customer: 'ZZZ Tap Me')]));

    await tester.tap(find.text('ZZZ Tap Me'));
    await tester.pumpAndSettle();

    expect(find.byType(HireDetailScreen), findsOneWidget);
  });

  testWidgets('the New Hire FAB opens the booking form with no vehicle preset', (tester) async {
    await _show(tester, FakeServer());

    await tester.tap(find.byKey(const Key('new-hire')));
    await tester.pumpAndSettle();

    final form = tester.widget<HireFormScreen>(find.byType(HireFormScreen));
    expect(form.vehicle, isNull);
  });

  testWidgets('the FAB is hidden without canCreateHires', (tester) async {
    await _show(tester, FakeServer()..canCreateHires = false);

    expect(find.byKey(const Key('new-hire')), findsNothing);
  });
}
