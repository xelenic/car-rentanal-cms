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

Future<void> _show(WidgetTester tester, FakeServer server, {AdminUser? user, bool settle = true}) async {
  tester.view.physicalSize = const Size(412, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await server.install();
  await tester.pumpWidget(MaterialApp(theme: buildAdminAppTheme(), home: MyExpensesScreen(user: user ?? _user())));
  await _quiet(tester, settle);
}

/// [settle] false is for a list with more pages to come: its bottom spinner
/// never stops, so waiting for the screen to go quiet would wait forever.
Future<void> _quiet(WidgetTester tester, bool settle) async {
  if (settle) {
    await tester.pumpAndSettle();
    return;
  }
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Iterable<Map<String, String>> _listQueries(FakeServer server) =>
    server.requestsTo('/api/admin/my-expenses').where((r) => r.method == 'GET').map((r) => r.url.queryParameters);

String _value(WidgetTester tester, String key) => tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

void main() {
  group('the cards', () {
    testWidgets('lead with My Profit, worked out as the month\'s profit less my expenses', (tester) async {
      await _show(tester, _server());

      // 6,400.00 - (1,500.50 + 499.50)
      expect(find.descendant(of: find.byKey(const Key('card-my-profit')), matching: find.text('Rs. 4,400.00')), findsOneWidget);
      expect(find.text('My Profit · $_thisMonthLabel'), findsOneWidget);
    });

    testWidgets('show the month\'s total, record count and the profit before my expenses', (tester) async {
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

    testWidgets('are for the whole month even while the list is filtered', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('category-filter-fuel')));
      await tester.pumpAndSettle();

      expect(find.descendant(of: find.byKey(const Key('card-total')), matching: find.text('Rs. 2,000.00')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('card-my-profit')), matching: find.text('Rs. 4,400.00')), findsOneWidget);
    });
  });

  group('the list', () {
    testWidgets('opens on this month and asks for it', (tester) async {
      final server = _server();
      await _show(tester, server);

      expect(_listQueries(server).first, {'year': '${_now.year}', 'month': '${_now.month}', 'page': '1'});
      expect(find.text(_thisMonthLabel), findsWidgets);
    });

    testWidgets('shows the month\'s expenses newest first, with category, date, notes and amount', (tester) async {
      await _show(tester, _server());

      expect(find.text('ZZZ Office rent'), findsOneWidget);
      expect(find.text('ZZZ Van fuel'), findsOneWidget);
      expect(find.text('ZZZ Last month rent'), findsNothing);
      expect(find.text('Rs. 1,500.50'), findsOneWidget); // cents shown
      expect(find.text('ZZZ monthly'), findsOneWidget);
      expect(find.text(DateFormat('EEE, MMM d').format(DateTime(_now.year, _now.month, 2))), findsOneWidget);
      expect(tester.getTopLeft(find.text('ZZZ Van fuel')).dy, lessThan(tester.getTopLeft(find.text('ZZZ Office rent')).dy));
    });

    testWidgets('says so when the month has no expenses', (tester) async {
      await _show(tester, FakeServer());

      expect(find.text('No expenses yet'), findsOneWidget);
      expect(find.text('Nothing recorded for $_thisMonthLabel.'), findsOneWidget);
    });

    testWidgets('shows the server\'s message and retries', (tester) async {
      final server = _server()..failWith = 500;
      await _show(tester, server);

      expect(find.text('The server said no.'), findsOneWidget);

      server.failWith = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('ZZZ Office rent'), findsOneWidget);
    });

    testWidgets('pages a long month as you scroll', (tester) async {
      final server = FakeServer(pageSize: 3, expenses: [
        for (var i = 1; i <= 5; i++) expenseJson(id: i, title: 'ZZZ expense $i', date: dayOf(_thisMonth, i)),
      ]);
      await _show(tester, server, settle: false);

      expect(_listQueries(server).map((q) => q['page']), ['1']);

      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await _quiet(tester, true);

      expect(_listQueries(server).map((q) => q['page']), ['1', '2']);
      expect(find.text('ZZZ expense 1'), findsOneWidget);
    });
  });

  group('changing month', () {
    testWidgets('the arrows step back and forward a month', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('month-prev')));
      await tester.pumpAndSettle();

      expect(_listQueries(server).last, {'year': '${_lastMonth.year}', 'month': '${_lastMonth.month}', 'page': '1'});
      expect(find.text('ZZZ Last month rent'), findsOneWidget);
      expect(find.text('ZZZ Office rent'), findsNothing);
      expect(find.text(_lastMonthLabel), findsWidgets);

      await tester.tap(find.byKey(const Key('month-next')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Office rent'), findsOneWidget);
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

  group('filtering the list', () {
    testWidgets('offers All and every category as chips', (tester) async {
      await _show(tester, _server());

      expect(find.byKey(const Key('category-filter-all')), findsOneWidget);
      expect(find.byKey(const Key('category-filter-rent')), findsOneWidget);
      expect(find.byKey(const Key('category-filter-fuel')), findsOneWidget);
    });

    testWidgets('a category narrows the list and says what the shown ones come to', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('category-filter-fuel')));
      await tester.pumpAndSettle();

      expect(_listQueries(server).last['category'], 'fuel');
      expect(find.text('ZZZ Van fuel'), findsOneWidget);
      expect(find.text('ZZZ Office rent'), findsNothing);
      expect(find.text('Total of the 1 expense shown: Rs. 499.50'), findsOneWidget);
    });

    testWidgets('All brings everything back', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('category-filter-fuel')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('category-filter-all')));
      await tester.pumpAndSettle();

      expect(_listQueries(server).last.containsKey('category'), isFalse);
      expect(find.text('ZZZ Office rent'), findsOneWidget);
      expect(find.byKey(const Key('filtered-total')), findsNothing);
    });

    testWidgets('searching the title or notes narrows the list', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.enterText(find.byKey(const Key('expense-search')), 'monthly');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(_listQueries(server).last['search'], 'monthly');
      expect(find.text('ZZZ Office rent'), findsOneWidget);
      expect(find.text('ZZZ Van fuel'), findsNothing);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await _show(tester, _server());

      await tester.enterText(find.byKey(const Key('expense-search')), 'zebra');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('No expenses match'), findsOneWidget);
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
      expect(inSheet('Profit Before My Expenses'), findsOneWidget);
      expect(inSheet('Rs. 6,400.00'), findsOneWidget);
      // My expenses by category, biggest first.
      expect(inSheet('Rent'), findsOneWidget);
      expect(inSheet('-Rs. 1,500.50'), findsOneWidget);
      expect(inSheet('Fuel'), findsOneWidget);
      expect(inSheet('-Rs. 499.50'), findsOneWidget);
      expect(inSheet('Total My Expenses'), findsOneWidget);
      expect(find.byKey(const Key('breakdown-my-profit')), findsOneWidget);
      expect(inSheet('Profit Before My Expenses (Rs. 6,400.00) − My Expenses (Rs. 2,000.00) = Rs. 4,400.00.'), findsOneWidget);
    });

    testWidgets('says when there are no expenses to take off', (tester) async {
      await _show(tester, FakeServer());

      await tester.tap(find.byKey(const Key('card-my-profit')));
      await tester.pumpAndSettle();

      expect(find.text('None recorded for $_thisMonthLabel.'), findsOneWidget);
    });
  });

  group('adding an expense', () {
    testWidgets('is offered to someone who may create expenses', (tester) async {
      await _show(tester, _server());

      expect(find.byKey(const Key('add-expense')), findsOneWidget);
    });

    testWidgets('is not offered to someone who may not', (tester) async {
      await _show(tester, _server(), user: _user(create: false));

      expect(find.byKey(const Key('add-expense')), findsNothing);
    });

    testWidgets('opens a blank form under Others, dated today', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsWidgets);
      expect(_value(tester, 'expense-title'), '');
      expect(find.text('Others'), findsOneWidget); // the dropdown's selection
      expect(find.text(DateFormat('EEE, MMM d, y').format(DateTime(_now.year, _now.month, _now.day))), findsOneWidget);
    });

    testWidgets('saves it, lands back on the list showing it, and confirms', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expense-title')), 'ZZZ New bill');
      await tester.enterText(find.byKey(const Key('expense-amount')), '250.75');
      await tester.enterText(find.byKey(const Key('expense-notes')), 'ZZZ paid in cash');
      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      final sent = server.savedExpenses.single;
      expect(sent.id, isNull);
      expect(sent.body['title'], 'ZZZ New bill');
      expect(sent.body['category'], 'others');
      expect(sent.body['amount'], '250.75');
      expect(sent.body['expense_date'], dayOf(_now, _now.day));
      expect(sent.body['notes'], 'ZZZ paid in cash');
      expect(sent.body.containsKey('new_category'), isFalse);

      expect(find.text('Add Expense'), findsOneWidget); // the button, not the form's title
      expect(find.text('ZZZ New bill added.'), findsOneWidget);
      expect(find.text('ZZZ New bill'), findsOneWidget);
      // The cards followed: 2,000.00 + 250.75 = 2,250.75; profit 6,400 - 2,250.75.
      expect(find.descendant(of: find.byKey(const Key('card-total')), matching: find.text('Rs. 2,250.75')), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('card-my-profit')), matching: find.text('Rs. 4,149.25')), findsOneWidget);
    });

    testWidgets('takes an expense without notes', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expense-title')), 'ZZZ Bare');
      await tester.enterText(find.byKey(const Key('expense-amount')), '10');
      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      expect(server.savedExpenses.single.body['notes'], isNull);
    });

    testWidgets('will not send an empty form, and says what is missing', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      expect(server.savedExpenses, isEmpty);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
    });

    testWidgets('will not send an amount of zero', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expense-title')), 'ZZZ Free');
      await tester.enterText(find.byKey(const Key('expense-amount')), '0');
      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      expect(server.savedExpenses, isEmpty);
      expect(find.text('Must be more than 0'), findsOneWidget);
    });

    testWidgets('can file it under a brand new category, which then shows up in the chips', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('new-category-name')), findsNothing);

      await tester.enterText(find.byKey(const Key('expense-title')), 'ZZZ Card fee');
      await tester.enterText(find.byKey(const Key('expense-amount')), '35');
      await tester.tap(find.byKey(const Key('expense-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('＋ Add new category…').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('new-category-name')), 'ZZZ Bank charges');
      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      final sent = server.savedExpenses.single.body;
      expect(sent['category'], '__new__');
      expect(sent['new_category'], 'ZZZ Bank charges');
      expect(find.byKey(const Key('category-filter-zzz-bank-charges')), findsOneWidget);
      expect(find.text('ZZZ Bank charges'), findsWidgets);
    });

    testWidgets('needs a name for a new category', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expense-title')), 'ZZZ Card fee');
      await tester.enterText(find.byKey(const Key('expense-amount')), '35');
      await tester.tap(find.byKey(const Key('expense-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('＋ Add new category…').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      expect(server.savedExpenses, isEmpty);
      expect(find.text('Type a name for the new category'), findsOneWidget);
    });

    testWidgets('shows the server\'s reason and stays on the form when it refuses', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();
      server.failMethods['POST'] = 422;

      await tester.enterText(find.byKey(const Key('expense-title')), 'ZZZ Refused');
      await tester.enterText(find.byKey(const Key('expense-amount')), '10');
      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('expense-error')), findsOneWidget);
      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.byKey(const Key('save-expense')), findsOneWidget); // still on the form
      expect(server.expenses.any((e) => e['title'] == 'ZZZ Refused'), isFalse);
    });

    testWidgets('an expense dated in another month takes you to that month', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('add-expense')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expense-title')), 'ZZZ Backdated');
      await tester.enterText(find.byKey(const Key('expense-amount')), '10');
      await tester.tap(find.byKey(const Key('expense-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      expect(server.savedExpenses.single.body['expense_date'], dayOf(_lastMonth, 15));
      expect(_listQueries(server).last, {'year': '${_lastMonth.year}', 'month': '${_lastMonth.month}', 'page': '1'});
      expect(find.text('ZZZ Backdated'), findsOneWidget);
      expect(find.text(_lastMonthLabel), findsWidgets);
    });
  });

  group('editing an expense', () {
    testWidgets('tapping one opens the form filled in with what it has', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('expense-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsOneWidget);
      expect(_value(tester, 'expense-title'), 'ZZZ Office rent');
      expect(_value(tester, 'expense-amount'), '1500.5');
      expect(_value(tester, 'expense-notes'), 'ZZZ monthly');
      expect(find.text('Rent'), findsWidgets);
      expect(find.text(DateFormat('EEE, MMM d, y').format(DateTime(_now.year, _now.month, 2))), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save Changes'), findsOneWidget);
    });

    testWidgets('saves the change to that expense and shows it', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('expense-1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('expense-title')), 'ZZZ Office rent (raised)');
      await tester.enterText(find.byKey(const Key('expense-amount')), '1800');
      await tester.tap(find.byKey(const Key('save-expense')));
      await tester.pumpAndSettle();

      final sent = server.savedExpenses.single;
      expect(sent.id, 1);
      expect(sent.body['title'], 'ZZZ Office rent (raised)');
      expect(sent.body['category'], 'rent');
      expect(sent.body['amount'], '1800');
      expect(server.expenses.where((e) => e['id'] == 1), hasLength(1)); // not duplicated
      expect(find.text('ZZZ Office rent (raised) updated.'), findsOneWidget);
      expect(find.text('Rs. 1,800.00'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const Key('card-total')), matching: find.text('Rs. 2,299.50')), findsOneWidget);
    });

    testWidgets('someone who may edit but not create is not offered "Add new category" while editing', (tester) async {
      await _show(tester, _server(), user: _user(create: false));
      await tester.tap(find.byKey(const Key('expense-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('expense-category')));
      await tester.pumpAndSettle();

      expect(find.text('Utilities'), findsWidgets); // the dropdown is open
      expect(find.text('＋ Add new category…'), findsNothing);
    });

    testWidgets('someone who may create is offered "Add new category" while editing too', (tester) async {
      await _show(tester, _server());
      await tester.tap(find.byKey(const Key('expense-1')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('expense-category')));
      await tester.pumpAndSettle();

      expect(find.text('＋ Add new category…'), findsOneWidget);
    });

    testWidgets('someone who may not edit cannot open one', (tester) async {
      await _show(tester, _server(), user: _user(update: false));

      await tester.tap(find.byKey(const Key('expense-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Expense'), findsNothing);
    });

    testWidgets('the menu offers Edit and Delete to someone who may do both', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('expense-menu-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('the menu offers only what the user may do', (tester) async {
      await _show(tester, _server(), user: _user(update: false));

      await tester.tap(find.byKey(const Key('expense-menu-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('no menu at all for someone who may neither edit nor delete', (tester) async {
      await _show(tester, _server(), user: _user(update: false, delete: false));

      expect(find.byKey(const Key('expense-menu-1')), findsNothing);
    });
  });

  group('deleting an expense', () {
    Future<void> openDelete(WidgetTester tester, int id) async {
      await tester.tap(find.byKey(Key('expense-menu-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, saying what comes off', (tester) async {
      final server = _server();
      await _show(tester, server);

      await openDelete(tester, 1);

      expect(find.text('Delete "ZZZ Office rent"?'), findsOneWidget);
      expect(find.textContaining('Rs. 1,500.50 comes off $_thisMonthLabel'), findsOneWidget);
      expect(server.deletedExpenses, isEmpty);
    });

    testWidgets('"Keep it" changes nothing', (tester) async {
      final server = _server();
      await _show(tester, server);
      await openDelete(tester, 1);

      await tester.tap(find.byKey(const Key('keep-expense')));
      await tester.pumpAndSettle();

      expect(server.deletedExpenses, isEmpty);
      expect(find.text('ZZZ Office rent'), findsOneWidget);
    });

    testWidgets('deletes it, updates the cards, and says so', (tester) async {
      final server = _server();
      await _show(tester, server);
      await openDelete(tester, 1);

      await tester.tap(find.byKey(const Key('confirm-delete-expense')));
      await tester.pumpAndSettle();

      expect(server.deletedExpenses, [1]);
      expect(find.text('ZZZ Office rent'), findsNothing);
      expect(find.text('ZZZ Van fuel'), findsOneWidget);
      expect(find.text('ZZZ Office rent deleted.'), findsOneWidget);
      // 6,400 - 499.50
      expect(find.descendant(of: find.byKey(const Key('card-my-profit')), matching: find.text('Rs. 5,900.50')), findsOneWidget);
    });

    testWidgets('keeps the expense and shows why when the server refuses', (tester) async {
      final server = _server();
      await _show(tester, server);
      server.failMethods['DELETE'] = 403;
      await openDelete(tester, 1);

      await tester.tap(find.byKey(const Key('confirm-delete-expense')));
      await tester.pumpAndSettle();

      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.text('ZZZ Office rent'), findsOneWidget);
    });
  });

  group('the categories button', () {
    testWidgets('is there for someone who may manage categories', (tester) async {
      await _show(tester, _server());

      expect(find.byKey(const Key('manage-categories')), findsOneWidget);
    });

    testWidgets('is not there for someone who may only look', (tester) async {
      await _show(tester, _server(), user: _user(create: false, update: false, delete: false));

      expect(find.byKey(const Key('manage-categories')), findsNothing);
    });

    testWidgets('opens the categories screen', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('manage-categories')));
      await tester.pumpAndSettle();

      expect(find.text('Expense Categories'), findsOneWidget);
    });
  });
}
