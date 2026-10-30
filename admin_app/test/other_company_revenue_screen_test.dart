import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/screens/other_company_revenue_list_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/fake_server.dart';

final _now = DateTime.now();
final _thisMonth = DateTime(_now.year, _now.month);
final _thisMonthLabel = DateFormat('MMMM y').format(_thisMonth);

AdminUser _user({bool create = true, bool update = true, bool delete = true}) => AdminUser(
      id: 1,
      name: 'ZZZ Test Admin',
      email: 'zzz@example.test',
      canCreateHires: true,
      canViewMyExpenses: true,
      canCreateMyExpenses: create,
      canUpdateMyExpenses: update,
      canDeleteMyExpenses: delete,
    );

/// Two revenue entries this month (together 9,000 balance), one last month.
FakeServer _server() => FakeServer(
      revenues: [
        revenueJson(id: 1, hire: 'ZZZ Colombo to Kandy', bookingNumber: 'ZZZ-BK-001', vehicle: 'ZZZ Aqua', balance: 7000, date: dayOf(_thisMonth, 2)),
        revenueJson(id: 2, hire: 'ZZZ Galle Fort Tour', bookingNumber: 'ZZZ-BK-002', vehicle: 'ZZZ Hiace', balance: 2000, date: dayOf(_thisMonth, 5)),
        revenueJson(id: 3, hire: 'ZZZ Last month trip', bookingNumber: 'ZZZ-BK-003', vehicle: 'ZZZ Prius', balance: 1000, date: dayOf(DateTime(_now.year, _now.month - 1), 12)),
      ],
    );

Future<void> _show(WidgetTester tester, FakeServer server, {AdminUser? user}) async {
  tester.view.physicalSize = const Size(412, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(
    theme: buildAdminAppTheme(),
    home: OtherCompanyRevenueListScreen(user: user ?? _user(), initialYear: _now.year, initialMonth: _now.month),
  ));
  await tester.pumpAndSettle();
}

Iterable<Map<String, String>> _revenueQueries(FakeServer server) =>
    server.requestsTo('/api/admin/other-company-revenues').where((r) => r.method == 'GET').map((r) => r.url.queryParameters);

void main() {
  group('the list', () {
    testWidgets('shows this month\'s revenue, newest first, leaving other months out', (tester) async {
      final server = _server();
      await _show(tester, server);

      expect(_revenueQueries(server).first, {'year': '${_now.year}', 'month': '${_now.month}', 'page': '1'});
      expect(find.text('ZZZ Galle Fort Tour'), findsOneWidget);
      expect(find.text('ZZZ Colombo to Kandy'), findsOneWidget);
      expect(find.text('ZZZ Last month trip'), findsNothing);
      expect(
        tester.getTopLeft(find.text('ZZZ Galle Fort Tour')).dy,
        lessThan(tester.getTopLeft(find.text('ZZZ Colombo to Kandy')).dy),
      );
    });

    testWidgets('shows the booking number, vehicle and balance for each entry', (tester) async {
      await _show(tester, _server());

      expect(find.text('ZZZ-BK-001'), findsOneWidget);
      expect(find.text('ZZZ Aqua'), findsOneWidget);
      expect(find.text('Rs. 7,000.00'), findsOneWidget);
    });

    testWidgets('has its own search hint', (tester) async {
      await _show(tester, _server());

      expect(find.text('Search hire, booking # or vehicle…'), findsOneWidget);
    });

    testWidgets('an empty month says so', (tester) async {
      await _show(tester, FakeServer());

      expect(find.text('No revenue from other companies yet'), findsOneWidget);
      expect(find.text('Nothing recorded for $_thisMonthLabel.'), findsOneWidget);
    });

    testWidgets('a failed load shows the server\'s message and retries', (tester) async {
      final server = _server()..failWith = 500;
      await _show(tester, server);

      expect(find.text('The server said no.'), findsOneWidget);

      server.failWith = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('ZZZ Galle Fort Tour'), findsOneWidget);
    });
  });

  group('the summary card', () {
    testWidgets('shows the month\'s full amount, vehicle amount and balance, leaving other months out', (tester) async {
      await _show(tester, _server());

      expect(find.text('2 entries this month'), findsOneWidget);
      // Full amount and vehicle amount default to 10,000 and 6,000 per entry; two entries this month.
      expect(find.descendant(of: find.byKey(const Key('revenue-summary-full')), matching: find.text('Rs. 20,000.00')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('revenue-summary-vehicle')), matching: find.text('Rs. 12,000.00')), findsOneWidget);
      // 7,000 + 2,000 balance; the third entry's 1,000 is last month and left out.
      expect(find.descendant(of: find.byKey(const Key('revenue-summary-balance')), matching: find.text('Rs. 9,000.00')), findsOneWidget);
    });

    testWidgets('is unaffected by a search that narrows the list', (tester) async {
      await _show(tester, _server());

      await tester.enterText(find.byKey(const Key('expense-search')), 'Galle');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('revenue-summary-balance')), matching: find.text('Rs. 9,000.00')), findsOneWidget);
    });

    testWidgets('says so when the month has none', (tester) async {
      await _show(tester, FakeServer());

      expect(find.text('0 entries this month'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('revenue-summary-balance')), matching: find.text('Rs. 0.00')), findsOneWidget);
    });
  });

  group('searching revenue', () {
    testWidgets('narrows the list and says what the balance matches come to', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.enterText(find.byKey(const Key('expense-search')), 'Galle');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(_revenueQueries(server).last['search'], 'Galle');
      expect(find.text('ZZZ Galle Fort Tour'), findsOneWidget);
      expect(find.text('ZZZ Colombo to Kandy'), findsNothing);
      expect(find.text('Balance total of the 1 entry shown: Rs. 2,000.00'), findsOneWidget);
    });
  });

  group('adding revenue', () {
    testWidgets('the button says Add Revenue', (tester) async {
      await _show(tester, _server());

      expect(find.byKey(const Key('add-revenue')), findsOneWidget);
      expect(find.widgetWithText(FloatingActionButton, 'Add Revenue'), findsOneWidget);
    });

    testWidgets('is not offered to someone who may not create', (tester) async {
      await _show(tester, _server(), user: _user(create: false));

      expect(find.byKey(const Key('add-revenue')), findsNothing);
    });

    testWidgets('opens a blank form with no bank slip chosen', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('add-revenue')));
      await tester.pumpAndSettle();

      expect(find.text('Add Revenue'), findsWidgets);
      expect(find.text('Add Photo of Bank Slip'), findsOneWidget);
    });

    testWidgets('has no Credited Amount field — only Balance counts toward My Profit', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('add-revenue')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('revenue-credited-amount')), findsNothing);
      expect(find.text('Credited Amount (Rs.)'), findsNothing);
    });

    testWidgets('saves it without a slip and shows it in the list', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-revenue')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('revenue-hire')), 'ZZZ Ella Trip');
      await tester.enterText(find.byKey(const Key('revenue-booking-number')), 'ZZZ-BK-777');
      await tester.enterText(find.byKey(const Key('revenue-vehicle')), 'ZZZ Prius — XYZ-999');
      await tester.enterText(find.byKey(const Key('revenue-full-amount')), '5000');
      await tester.enterText(find.byKey(const Key('revenue-balance')), '2000');
      await tester.enterText(find.byKey(const Key('revenue-vehicle-amount')), '2500');
      await tester.tap(find.byKey(const Key('save-revenue')));
      await tester.pumpAndSettle();

      final sent = server.savedRevenues.single;
      expect(sent.id, isNull);
      expect(sent.fields['hire'], 'ZZZ Ella Trip');
      expect(sent.fields['booking_number'], 'ZZZ-BK-777');
      // Hidden from the form — a new entry always starts at 0.
      expect(sent.fields['credited_amount'], '0');
      expect(sent.slipFilename, isNull);

      expect(find.text('ZZZ Ella Trip added.'), findsOneWidget);
      expect(find.text('ZZZ Ella Trip'), findsOneWidget);
    });

    testWidgets('will not save an empty form, and says so', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-revenue')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-revenue')));
      await tester.pumpAndSettle();

      expect(server.savedRevenues, isEmpty);
      expect(find.text('Required'), findsWidgets);
    });

    testWidgets('a negative balance is accepted', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-revenue')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('revenue-hire')), 'ZZZ Overpaid Trip');
      await tester.enterText(find.byKey(const Key('revenue-booking-number')), 'ZZZ-BK-888');
      await tester.enterText(find.byKey(const Key('revenue-vehicle')), 'ZZZ Van');
      await tester.enterText(find.byKey(const Key('revenue-full-amount')), '1000');
      await tester.enterText(find.byKey(const Key('revenue-balance')), '-200');
      await tester.enterText(find.byKey(const Key('revenue-vehicle-amount')), '500');
      await tester.tap(find.byKey(const Key('save-revenue')));
      await tester.pumpAndSettle();

      expect(server.savedRevenues.single.fields['balance'], '-200');
      expect(find.text('ZZZ Overpaid Trip added.'), findsOneWidget);
    });
  });

  group('editing and deleting revenue', () {
    testWidgets('tapping one opens the form filled in with what it has', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.text('ZZZ Colombo to Kandy'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Revenue'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('revenue-hire'))).controller!.text,
        'ZZZ Colombo to Kandy',
      );
      expect(
        tester.widget<TextFormField>(find.byKey(const Key('revenue-booking-number'))).controller!.text,
        'ZZZ-BK-001',
      );
    });

    testWidgets('no menu at all for someone who may neither edit nor delete', (tester) async {
      await _show(tester, _server(), user: _user(update: false, delete: false));

      expect(find.byKey(const Key('revenue-menu-1')), findsNothing);
    });

    testWidgets('saves a change and shows it', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.text('ZZZ Colombo to Kandy'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('revenue-balance')), '7500');
      await tester.tap(find.byKey(const Key('save-revenue')));
      await tester.pumpAndSettle();

      expect(server.savedRevenues.single.id, 1);
      // Hidden from the form, so editing for an unrelated reason doesn't
      // touch it — still whatever it already had (the fixture's 7,000).
      expect(server.savedRevenues.single.fields['credited_amount'], '7000');
      expect(find.text('Rs. 7,500.00'), findsOneWidget);
    });

    testWidgets('asks first, then deletes', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('revenue-menu-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete "ZZZ Galle Fort Tour"?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('confirm-delete-revenue')));
      await tester.pumpAndSettle();

      expect(server.deletedRevenues, [2]);
      expect(find.text('ZZZ Galle Fort Tour deleted.'), findsOneWidget);
      expect(find.text('ZZZ Galle Fort Tour'), findsNothing);
    });

    testWidgets('"Keep it" changes nothing', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('revenue-menu-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('keep-revenue')));
      await tester.pumpAndSettle();

      expect(server.deletedRevenues, isEmpty);
      expect(find.text('ZZZ Galle Fort Tour'), findsOneWidget);
    });
  });

  group('the bank slip', () {
    testWidgets('a clip icon shows for an entry that has one', (tester) async {
      await _show(
        tester,
        FakeServer(revenues: [
          revenueJson(id: 1, hire: 'ZZZ With Slip', date: dayOf(_thisMonth, 2), slipUrl: 'http://localhost/fake-slip/slip.jpg'),
          revenueJson(id: 2, hire: 'ZZZ No Slip', date: dayOf(_thisMonth, 3)),
        ]),
      );

      expect(
        find.descendant(of: find.byKey(const Key('revenue-1')), matching: find.byIcon(Icons.attach_file_rounded)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byKey(const Key('revenue-2')), matching: find.byIcon(Icons.attach_file_rounded)),
        findsNothing,
      );
    });

    testWidgets('editing an entry with a slip shows it already attached', (tester) async {
      await _show(
        tester,
        FakeServer(revenues: [
          revenueJson(id: 1, hire: 'ZZZ With Slip', date: dayOf(_thisMonth, 2), slipUrl: 'http://localhost/fake-slip/slip.jpg'),
        ]),
      );

      await tester.tap(find.text('ZZZ With Slip'));
      await tester.pumpAndSettle();

      expect(find.text('Add Photo of Bank Slip'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('saving an edit without picking a new photo sends no slip file', (tester) async {
      final server = FakeServer(revenues: [
        revenueJson(id: 1, hire: 'ZZZ With Slip', date: dayOf(_thisMonth, 2), slipUrl: 'http://localhost/fake-slip/slip.jpg'),
      ]);
      await _show(tester, server);

      await tester.tap(find.text('ZZZ With Slip'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-revenue')));
      await tester.pumpAndSettle();

      expect(server.savedRevenues.single.slipFilename, isNull);
    });
  });
}
