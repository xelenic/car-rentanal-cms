import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/screens/my_expenses_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:admin_app/widgets/profit_breakdown_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/fake_server.dart';

final _now = DateTime.now();
final _thisMonth = DateTime(_now.year, _now.month);
final _lastMonth = DateTime(_now.year, _now.month - 1);
final _thisMonthLabel = DateFormat('MMMM y').format(_thisMonth);
final _lastMonthLabel = DateFormat('MMMM y').format(_lastMonth);

AdminUser _user({bool view = true, bool create = true, bool update = true, bool delete = true}) => AdminUser(
      id: 1,
      name: 'ZZZ Test Admin',
      email: 'zzz@example.test',
      canCreateHires: true,
      canViewMyExpenses: view,
      canCreateMyExpenses: create,
      canUpdateMyExpenses: update,
      canDeleteMyExpenses: delete,
    );

/// Two expenses this month (Rent 1,500.50 and Fuel 499.50), one last month.
FakeServer _server() => FakeServer(
      profitBeforeExpenses: 6400,
      expenses: [
        expenseJson(id: 1, title: 'ZZZ Office rent', category: 'rent', categoryName: 'Rent', amount: 1500.5, date: dayOf(_thisMonth, 2), notes: 'ZZZ monthly'),
        expenseJson(id: 2, title: 'ZZZ Van fuel', category: 'fuel', categoryName: 'Fuel', amount: 499.5, date: dayOf(_thisMonth, 5)),
        expenseJson(id: 3, title: 'ZZZ Last month rent', category: 'rent', categoryName: 'Rent', amount: 900, date: dayOf(_lastMonth, 20)),
      ],
    );

Future<void> _show(WidgetTester tester, FakeServer server, {AdminUser? user}) async {
  tester.view.physicalSize = const Size(412, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: MyExpensesScreen(user: user ?? _user())));
  await tester.pumpAndSettle();
}

Iterable<Map<String, String>> _listQueries(FakeServer server) =>
    server.requestsTo('/api/admin/my-expenses').where((r) => r.method == 'GET').map((r) => r.url.queryParameters);

void main() {
  group('the cards', () {
    testWidgets('lead with My Profit, worked out as the month\'s profit less my expenses', (tester) async {
      await _show(tester, _server());

      // 6,400.00 - (1,500.50 + 499.50)
      expect(find.descendant(of: find.byKey(const Key('card-my-profit')), matching: find.text('Rs. 4,400.00')), findsOneWidget);
      expect(find.text('My Profit · $_thisMonthLabel'), findsOneWidget);
    });

    testWidgets('show the month\'s total, record count and the profit from hires', (tester) async {
      await _show(tester, _server());

      final total = find.byKey(const Key('card-total'));
      expect(find.descendant(of: total, matching: find.text('Rs. 2,000.00')), findsOneWidget);
      expect(find.descendant(of: total, matching: find.text('2 records')), findsOneWidget);
      final before = find.byKey(const Key('card-profit-before'));
      expect(find.descendant(of: before, matching: find.text('Rs. 6,400.00')), findsOneWidget);
    });

    testWidgets('show a loss with a minus sign', (tester) async {
      final server = _server()..profitBeforeExpenses = 800;
      await _show(tester, server);

      expect(find.descendant(of: find.byKey(const Key('card-my-profit')), matching: find.text('-Rs. 1,200.00')), findsOneWidget);
    });
  });

  group('the section grid', () {
    testWidgets('offers Expenses, Other Income and Other Company Revenue, each with a record count', (tester) async {
      final server = _server()
        ..otherIncomeTotal = 500
        ..otherIncomeCount = 1;
      await _show(tester, server);

      expect(find.byKey(const Key('section-expenses')), findsOneWidget);
      expect(find.byKey(const Key('section-income')), findsOneWidget);
      expect(find.byKey(const Key('section-revenue')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('section-expenses')), matching: find.text('2 entries')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('section-income')), matching: find.text('1 entry')), findsOneWidget);
    });

    testWidgets('Expenses opens the expenses list for the same month', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('section-expenses')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Office rent'), findsOneWidget);
      expect(find.byKey(const Key('add-expense')), findsOneWidget);
    });

    testWidgets('Other Income opens the income list', (tester) async {
      final server = FakeServer(incomes: [incomeJson(id: 1, title: 'ZZZ Shop rent', date: dayOf(_thisMonth, 2))]);
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('section-income')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Shop rent'), findsOneWidget);
      expect(find.byKey(const Key('add-income')), findsOneWidget);
    });

    testWidgets('Other Company Revenue opens the revenue list', (tester) async {
      final server = FakeServer(revenues: [revenueJson(id: 1, hire: 'ZZZ Colombo to Kandy', date: dayOf(_thisMonth, 2))]);
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('section-revenue')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Colombo to Kandy'), findsOneWidget);
      expect(find.byKey(const Key('add-revenue')), findsOneWidget);
    });

    testWidgets('coming back refreshes My Profit and the counts', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('section-expenses')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('expense-title')), 'ZZZ New bill');
      await tester.enterText(find.byKey(const Key('expense-amount')), '100');
      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('section-expenses')), matching: find.text('3 entries')), findsOneWidget);
      // 6,400 - (1,500.50 + 499.50 + 100)
      expect(find.descendant(of: find.byKey(const Key('card-my-profit')), matching: find.text('Rs. 4,300.00')), findsOneWidget);
    });
  });

  group('changing month', () {
    testWidgets('the arrows step back and forward a month', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('month-prev')));
      await tester.pumpAndSettle();

      expect(_listQueries(server).last, {'year': '${_lastMonth.year}', 'month': '${_lastMonth.month}', 'page': '1'});
      expect(find.text(_lastMonthLabel), findsWidgets);

      await tester.tap(find.byKey(const Key('month-next')));
      await tester.pumpAndSettle();

      expect(find.text(_thisMonthLabel), findsWidgets);
    });

    testWidgets('stepping back from January goes to December of the year before', (tester) async {
      final server = FakeServer();
      await _show(tester, server);
      // Walk back to January of this year, then one more.
      for (var i = 1; i < _now.month; i++) {
        await tester.tap(find.byKey(const Key('month-prev')));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byKey(const Key('month-prev')));
      await tester.pumpAndSettle();

      expect(_listQueries(server).last, {'year': '${_now.year - 1}', 'month': '12', 'page': '1'});
    });

    testWidgets('tapping the month name offers any year and month', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('month-label')));
      await tester.pumpAndSettle();
      expect(find.text('Choose a month'), findsOneWidget);
      await tester.tap(find.byKey(const Key('picker-month-1')));
      await tester.pumpAndSettle();

      expect(_listQueries(server).last, {'year': '${_now.year}', 'month': '1', 'page': '1'});
      expect(find.text('January ${_now.year}'), findsWidgets);
    });

    testWidgets('the picker can pick another year', (tester) async {
      final server = _server();
      server.expenses.add(expenseJson(id: 9, date: '${_now.year - 1}-03-10'));
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('month-label')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('picker-year')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('${_now.year - 1}').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('picker-month-3')));
      await tester.pumpAndSettle();

      expect(_listQueries(server).last, {'year': '${_now.year - 1}', 'month': '3', 'page': '1'});
      expect(find.text('March ${_now.year - 1}'), findsWidgets);
    });
  });

  group('how My Profit is worked out', () {
    testWidgets('tapping the card shows the calculation, line by line', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('card-my-profit')));
      await tester.pumpAndSettle();

      // The cards behind the sheet repeat some of these figures, so look only inside it.
      final sheet = find.byType(ProfitBreakdownSheet);
      Finder inSheet(String text) => find.descendant(of: sheet, matching: find.text(text));

      expect(inSheet('My Profit — $_thisMonthLabel'), findsOneWidget);
      expect(inSheet('Total Our Hire Value'), findsOneWidget);
      expect(inSheet('Rs. 8,000.00'), findsOneWidget);
      expect(inSheet('Less: Driver Salary (20%)'), findsOneWidget);
      expect(inSheet('-Rs. 1,600.00'), findsOneWidget);
      expect(inSheet('Less: Leasing Installments'), findsOneWidget);
      expect(inSheet('Less: Vehicle Repair Cost'), findsOneWidget);
      expect(inSheet('Profit From Hires'), findsOneWidget);
      expect(inSheet('Add: Other Income (0 entries)'), findsOneWidget);
      expect(inSheet('Rs. 6,400.00'), findsOneWidget);
      // My expenses by category, biggest first.
      expect(inSheet('Rent'), findsOneWidget);
      expect(inSheet('-Rs. 1,500.50'), findsOneWidget);
      expect(inSheet('Fuel'), findsOneWidget);
      expect(inSheet('-Rs. 499.50'), findsOneWidget);
      expect(inSheet('Total My Expenses'), findsOneWidget);
      expect(find.byKey(const Key('breakdown-my-profit')), findsOneWidget);
      expect(
        inSheet(
          'Profit From Hires (Rs. 6,400.00) + Other Income (Rs. 0.00) + Other Company Revenue (Rs. 0.00) '
          '− My Expenses (Rs. 2,000.00) = Rs. 4,400.00.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('adds other income into My Profit and shows it as its own line', (tester) async {
      final server = _server()
        ..otherIncomeTotal = 1750.5
        ..otherIncomeCount = 2;
      await _show(tester, server);

      // 6,400 + 1,750.50 - 2,000
      expect(find.descendant(of: find.byKey(const Key('card-my-profit')), matching: find.text('Rs. 6,150.50')), findsOneWidget);

      await tester.tap(find.byKey(const Key('card-my-profit')));
      await tester.pumpAndSettle();

      final sheet = find.byType(ProfitBreakdownSheet);
      Finder inSheet(String text) => find.descendant(of: sheet, matching: find.text(text));
      expect(inSheet('Add: Other Income (2 entries)'), findsOneWidget);
      expect(inSheet('+Rs. 1,750.50'), findsOneWidget);
      expect(
        inSheet(
          'Profit From Hires (Rs. 6,400.00) + Other Income (Rs. 1,750.50) + Other Company Revenue (Rs. 0.00) '
          '− My Expenses (Rs. 2,000.00) = Rs. 6,150.50.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says "1 entry" for a single piece of other income', (tester) async {
      final server = _server()
        ..otherIncomeTotal = 500
        ..otherIncomeCount = 1;
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('card-my-profit')));
      await tester.pumpAndSettle();

      expect(find.text('Add: Other Income (1 entry)'), findsOneWidget);
    });

    testWidgets('says when there are no expenses to take off', (tester) async {
      await _show(tester, FakeServer());

      await tester.tap(find.byKey(const Key('card-my-profit')));
      await tester.pumpAndSettle();

      expect(find.text('None recorded for $_thisMonthLabel.'), findsOneWidget);
    });
  });
}
