import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/screens/my_expenses_screen.dart';
import 'package:admin_app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'support/fake_server.dart';

final _now = DateTime.now();
final _thisMonth = DateTime(_now.year, _now.month);
final _lastMonth = DateTime(_now.year, _now.month - 1);
final _thisMonthLabel = DateFormat('MMMM y').format(_thisMonth);
final _lastMonthLabel = DateFormat('MMMM y').format(_lastMonth);

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

/// Two expenses (2,000.00 together) and two pieces of other income (1,750.50)
/// this month, one of each last month. Profit from hires is 6,400.
FakeServer _server() => FakeServer(
      profitBeforeExpenses: 6400,
      expenses: [
        expenseJson(id: 1, title: 'ZZZ Office rent', category: 'rent', categoryName: 'Rent', amount: 1500.5, date: dayOf(_thisMonth, 2)),
        expenseJson(id: 2, title: 'ZZZ Van fuel', category: 'fuel', categoryName: 'Fuel', amount: 499.5, date: dayOf(_thisMonth, 5)),
        expenseJson(id: 3, title: 'ZZZ Last month rent', category: 'rent', categoryName: 'Rent', amount: 900, date: dayOf(_lastMonth, 20)),
      ],
      incomes: [
        incomeJson(id: 1, title: 'ZZZ Shop rent', amount: 1500, date: dayOf(_thisMonth, 2), notes: 'ZZZ keys handed over'),
        incomeJson(id: 2, title: 'ZZZ Interest', amount: 250.5, date: dayOf(_thisMonth, 5)),
        incomeJson(id: 3, title: 'ZZZ Last month sale', amount: 700, date: dayOf(_lastMonth, 12)),
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

Future<void> _openIncome(WidgetTester tester, FakeServer server, {AdminUser? user}) async {
  await _show(tester, server, user: user);
  await tester.tap(find.byKey(const Key('tab-income')));
  await tester.pumpAndSettle();
}

Iterable<Map<String, String>> _incomeQueries(FakeServer server) =>
    server.requestsTo('/api/admin/other-incomes').where((r) => r.method == 'GET').map((r) => r.url.queryParameters);

String _value(WidgetTester tester, String key) => tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

Finder _inCard(String key, String text) => find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

void main() {
  group('the tabs', () {
    testWidgets('are Expenses and Other Income, each with how many entries the month has', (tester) async {
      await _show(tester, _server());

      expect(_inCard('tab-expenses', 'Expenses'), findsOneWidget);
      expect(_inCard('tab-expenses', '2'), findsOneWidget);
      expect(_inCard('tab-income', 'Other Income'), findsOneWidget);
      expect(_inCard('tab-income', '2'), findsOneWidget);
    });

    testWidgets('open on Expenses, without asking for the income list', (tester) async {
      final server = _server();
      await _show(tester, server);

      expect(find.text('ZZZ Office rent'), findsOneWidget);
      expect(find.text('ZZZ Shop rent'), findsNothing);
      expect(_incomeQueries(server), isEmpty);
    });

    testWidgets('Other Income shows the month\'s income, newest first, with notes and amounts', (tester) async {
      final server = _server();
      await _openIncome(tester, server);

      expect(_incomeQueries(server).first, {'year': '${_now.year}', 'month': '${_now.month}', 'page': '1'});
      expect(find.text('ZZZ Shop rent'), findsOneWidget);
      expect(find.text('ZZZ Interest'), findsOneWidget);
      expect(find.text('ZZZ Last month sale'), findsNothing);
      expect(find.text('ZZZ Office rent'), findsNothing);
      expect(find.text('ZZZ keys handed over'), findsOneWidget);
      expect(find.text('Rs. 1,500.00'), findsOneWidget);
      expect(find.text('Rs. 250.50'), findsOneWidget);
      expect(tester.getTopLeft(find.text('ZZZ Interest')).dy, lessThan(tester.getTopLeft(find.text('ZZZ Shop rent')).dy));
    });

    testWidgets('Other Income has no category chips and its own search hint', (tester) async {
      await _openIncome(tester, _server());

      expect(find.byKey(const Key('category-filter-all')), findsNothing);
      expect(find.text('Search income or notes…'), findsOneWidget);
    });

    testWidgets('going back to Expenses shows the expenses and the category chips again', (tester) async {
      await _openIncome(tester, _server());

      await tester.tap(find.byKey(const Key('tab-expenses')));
      await tester.pumpAndSettle();

      expect(find.text('ZZZ Office rent'), findsOneWidget);
      expect(find.text('ZZZ Shop rent'), findsNothing);
      expect(find.byKey(const Key('category-filter-all')), findsOneWidget);
    });

    testWidgets('leave a search or category behind rather than carrying it to the other list', (tester) async {
      final server = _server();
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('category-filter-fuel')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('expense-search')), 'van');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('tab-income')));
      await tester.pumpAndSettle();

      expect(_incomeQueries(server).last.containsKey('search'), isFalse);
      expect(find.text('ZZZ Shop rent'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('expense-search'))).controller!.text, '');

      await tester.tap(find.byKey(const Key('tab-expenses')));
      await tester.pumpAndSettle();
      expect(find.text('ZZZ Office rent'), findsOneWidget); // no leftover "fuel" filter
    });

    testWidgets('the month arrows keep the tab and step the income', (tester) async {
      final server = _server();
      await _openIncome(tester, server);

      await tester.tap(find.byKey(const Key('month-prev')));
      await tester.pumpAndSettle();

      expect(_incomeQueries(server).last, {'year': '${_lastMonth.year}', 'month': '${_lastMonth.month}', 'page': '1'});
      expect(find.text('ZZZ Last month sale'), findsOneWidget);
      expect(find.text('ZZZ Shop rent'), findsNothing);
      expect(find.text(_lastMonthLabel), findsWidgets);
    });

    testWidgets('an empty month says so', (tester) async {
      await _openIncome(tester, FakeServer());

      expect(find.text('No other income yet'), findsOneWidget);
      expect(find.text('Nothing recorded for $_thisMonthLabel.'), findsOneWidget);
    });

    testWidgets('a failed load shows the server\'s message and retries', (tester) async {
      final server = _server();
      await _show(tester, server);
      server.failWith = 500;
      await tester.tap(find.byKey(const Key('tab-income')));
      await tester.pumpAndSettle();

      expect(find.text('The server said no.'), findsOneWidget);

      server.failWith = null;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('ZZZ Shop rent'), findsOneWidget);
    });

    testWidgets('a long month of income pages as you scroll', (tester) async {
      final server = FakeServer(pageSize: 3, incomes: [
        for (var i = 1; i <= 5; i++) incomeJson(id: i, title: 'ZZZ income $i', date: dayOf(_thisMonth, i)),
      ]);
      await _show(tester, server);
      await tester.tap(find.byKey(const Key('tab-income')));
      await _quiet(tester, false);

      expect(_incomeQueries(server).map((q) => q['page']), ['1']);

      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await _quiet(tester, true);

      expect(_incomeQueries(server).map((q) => q['page']), ['1', '2']);
      expect(find.text('ZZZ income 1'), findsOneWidget);
    });
  });

  group('the cards', () {
    testWidgets('show Profit From Hires, Other Income and My Expenses — and My Profit as the three combined', (tester) async {
      await _show(tester, _server());

      expect(_inCard('card-profit-before', 'Rs. 6,400.00'), findsOneWidget);
      expect(_inCard('card-other-income', 'Rs. 1,750.50'), findsOneWidget);
      expect(_inCard('card-other-income', '2 entries'), findsOneWidget);
      expect(_inCard('card-total', 'Rs. 2,000.00'), findsOneWidget);
      expect(_inCard('card-my-profit', 'Rs. 6,150.50'), findsOneWidget); // 6,400 + 1,750.50 - 2,000
    });

    testWidgets('are the same on the Other Income tab', (tester) async {
      await _openIncome(tester, _server());

      expect(_inCard('card-other-income', 'Rs. 1,750.50'), findsOneWidget);
      expect(_inCard('card-my-profit', 'Rs. 6,150.50'), findsOneWidget);
    });

    testWidgets('say "1 entry" for a single piece of income', (tester) async {
      final server = FakeServer(incomes: [incomeJson(id: 1, date: dayOf(_thisMonth, 3))]);
      await _show(tester, server);

      expect(_inCard('card-other-income', '1 entry'), findsOneWidget);
    });

    testWidgets('are for the whole month even while income is searched', (tester) async {
      await _openIncome(tester, _server());

      await tester.enterText(find.byKey(const Key('expense-search')), 'interest');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(_inCard('card-other-income', 'Rs. 1,750.50'), findsOneWidget);
      expect(_inCard('card-my-profit', 'Rs. 6,150.50'), findsOneWidget);
    });
  });

  group('searching income', () {
    testWidgets('narrows the list and says what the matches come to', (tester) async {
      final server = _server();
      await _openIncome(tester, server);

      await tester.enterText(find.byKey(const Key('expense-search')), 'keys');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(_incomeQueries(server).last['search'], 'keys');
      expect(find.text('ZZZ Shop rent'), findsOneWidget);
      expect(find.text('ZZZ Interest'), findsNothing);
      expect(find.text('Total of the 1 entry shown: Rs. 1,500.00'), findsOneWidget);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await _openIncome(tester, _server());

      await tester.enterText(find.byKey(const Key('expense-search')), 'zebra');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('No income matches'), findsOneWidget);
      expect(find.text('Try a different search.'), findsOneWidget);
    });
  });

  group('adding income', () {
    testWidgets('the button says Add Income on this tab, and Add Expense on the other', (tester) async {
      await _show(tester, _server());
      expect(find.byKey(const Key('add-expense')), findsOneWidget);
      expect(find.byKey(const Key('add-income')), findsNothing);

      await tester.tap(find.byKey(const Key('tab-income')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add-income')), findsOneWidget);
      expect(find.byKey(const Key('add-expense')), findsNothing);
      expect(find.widgetWithText(FloatingActionButton, 'Add Income'), findsOneWidget);
    });

    testWidgets('is not offered to someone who may not create', (tester) async {
      await _openIncome(tester, _server(), user: _user(create: false));

      expect(find.byKey(const Key('add-income')), findsNothing);
    });

    testWidgets('opens a blank form, dated today', (tester) async {
      await _openIncome(tester, _server());

      await tester.tap(find.byKey(const Key('add-income')));
      await tester.pumpAndSettle();

      expect(find.text('Add Income'), findsWidgets);
      expect(_value(tester, 'income-title'), '');
      expect(_value(tester, 'income-amount'), '');
      expect(find.text(DateFormat('EEE, MMM d, y').format(DateTime(_now.year, _now.month, _now.day))), findsOneWidget);
      expect(find.byKey(const Key('expense-category')), findsNothing); // income has no category
    });

    testWidgets('saves it, shows it in the list, and moves the cards', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      await tester.tap(find.byKey(const Key('add-income')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('income-title')), 'ZZZ Dividend');
      await tester.enterText(find.byKey(const Key('income-amount')), '250.75');
      await tester.enterText(find.byKey(const Key('income-notes')), 'ZZZ paid by bank');
      await tester.tap(find.byKey(const Key('save-income')));
      await tester.pumpAndSettle();

      final sent = server.savedIncomes.single;
      expect(sent.id, isNull);
      expect(sent.body['title'], 'ZZZ Dividend');
      expect(sent.body['amount'], '250.75');
      expect(sent.body['income_date'], dayOf(_now, _now.day));
      expect(sent.body['notes'], 'ZZZ paid by bank');

      expect(find.text('ZZZ Dividend added.'), findsOneWidget);
      expect(find.text('ZZZ Dividend'), findsOneWidget);
      expect(find.text('Rs. 250.75'), findsOneWidget);
      // 1,750.50 + 250.75 = 2,001.25 of income; profit 6,400 + 2,001.25 - 2,000.
      expect(_inCard('card-other-income', 'Rs. 2,001.25'), findsOneWidget);
      expect(_inCard('card-other-income', '3 entries'), findsOneWidget);
      expect(_inCard('card-my-profit', 'Rs. 6,401.25'), findsOneWidget);
      expect(_inCard('tab-income', '3'), findsOneWidget);
    });

    testWidgets('takes income without notes', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      await tester.tap(find.byKey(const Key('add-income')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('income-title')), 'ZZZ Bare');
      await tester.enterText(find.byKey(const Key('income-amount')), '10');
      await tester.tap(find.byKey(const Key('save-income')));
      await tester.pumpAndSettle();

      expect(server.savedIncomes.single.body['notes'], isNull);
    });

    testWidgets('will not send an empty form, and says what is missing', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      await tester.tap(find.byKey(const Key('add-income')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('save-income')));
      await tester.pumpAndSettle();

      expect(server.savedIncomes, isEmpty);
      expect(find.text('Required'), findsOneWidget);
      expect(find.text('Enter an amount'), findsOneWidget);
    });

    testWidgets('will not send an amount of zero', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      await tester.tap(find.byKey(const Key('add-income')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('income-title')), 'ZZZ Free');
      await tester.enterText(find.byKey(const Key('income-amount')), '0');
      await tester.tap(find.byKey(const Key('save-income')));
      await tester.pumpAndSettle();

      expect(server.savedIncomes, isEmpty);
      expect(find.text('Must be more than 0'), findsOneWidget);
    });

    testWidgets('shows the server\'s reason and stays on the form when it refuses', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      await tester.tap(find.byKey(const Key('add-income')));
      await tester.pumpAndSettle();
      server.failMethods['POST'] = 422;

      await tester.enterText(find.byKey(const Key('income-title')), 'ZZZ Refused');
      await tester.enterText(find.byKey(const Key('income-amount')), '10');
      await tester.tap(find.byKey(const Key('save-income')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('income-error')), findsOneWidget);
      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.byKey(const Key('save-income')), findsOneWidget);
      expect(server.incomes.any((i) => i['title'] == 'ZZZ Refused'), isFalse);
    });

    testWidgets('income dated in another month takes you to that month', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      await tester.tap(find.byKey(const Key('add-income')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('income-title')), 'ZZZ Backdated');
      await tester.enterText(find.byKey(const Key('income-amount')), '10');
      await tester.tap(find.byKey(const Key('income-date')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15').first);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-income')));
      await tester.pumpAndSettle();

      expect(server.savedIncomes.single.body['income_date'], dayOf(_lastMonth, 15));
      expect(_incomeQueries(server).last, {'year': '${_lastMonth.year}', 'month': '${_lastMonth.month}', 'page': '1'});
      expect(find.text('ZZZ Backdated'), findsOneWidget);
      expect(find.text(_lastMonthLabel), findsWidgets);
    });
  });

  group('editing income', () {
    testWidgets('tapping an entry opens the form filled in with what it has', (tester) async {
      await _openIncome(tester, _server());

      await tester.tap(find.byKey(const Key('income-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Income'), findsOneWidget);
      expect(_value(tester, 'income-title'), 'ZZZ Shop rent');
      expect(_value(tester, 'income-amount'), '1500');
      expect(_value(tester, 'income-notes'), 'ZZZ keys handed over');
      expect(find.text(DateFormat('EEE, MMM d, y').format(DateTime(_now.year, _now.month, 2))), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save Changes'), findsOneWidget);
    });

    testWidgets('saves the change to that entry, and the cards follow', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      await tester.tap(find.byKey(const Key('income-1')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('income-title')), 'ZZZ Shop rent (raised)');
      await tester.enterText(find.byKey(const Key('income-amount')), '2000');
      await tester.tap(find.byKey(const Key('save-income')));
      await tester.pumpAndSettle();

      final sent = server.savedIncomes.single;
      expect(sent.id, 1);
      expect(sent.body['title'], 'ZZZ Shop rent (raised)');
      expect(sent.body['amount'], '2000');
      expect(server.incomes.where((i) => i['id'] == 1), hasLength(1)); // not duplicated
      expect(find.text('ZZZ Shop rent (raised) updated.'), findsOneWidget);
      expect(find.text('Rs. 2,000.00'), findsWidgets);
      expect(_inCard('card-other-income', 'Rs. 2,250.50'), findsOneWidget); // 2,000 + 250.50
      expect(_inCard('card-my-profit', 'Rs. 6,650.50'), findsOneWidget); // 6,400 + 2,250.50 - 2,000
    });

    testWidgets('someone who may not edit cannot open one', (tester) async {
      await _openIncome(tester, _server(), user: _user(update: false));

      await tester.tap(find.byKey(const Key('income-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Income'), findsNothing);
    });

    testWidgets('the menu offers what the user may do', (tester) async {
      await _openIncome(tester, _server(), user: _user(update: false));

      await tester.tap(find.byKey(const Key('income-menu-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('no menu at all for someone who may neither edit nor delete', (tester) async {
      await _openIncome(tester, _server(), user: _user(update: false, delete: false));

      expect(find.byKey(const Key('income-menu-1')), findsNothing);
    });
  });

  group('deleting income', () {
    Future<void> openDelete(WidgetTester tester, int id) async {
      await tester.tap(find.byKey(Key('income-menu-$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
    }

    testWidgets('asks first, saying what comes out', (tester) async {
      final server = _server();
      await _openIncome(tester, server);

      await openDelete(tester, 1);

      expect(find.text('Delete "ZZZ Shop rent"?'), findsOneWidget);
      expect(find.textContaining('Rs. 1,500.00 comes out of $_thisMonthLabel'), findsOneWidget);
      expect(server.deletedIncomes, isEmpty);
    });

    testWidgets('"Keep it" changes nothing', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      await openDelete(tester, 1);

      await tester.tap(find.byKey(const Key('keep-income')));
      await tester.pumpAndSettle();

      expect(server.deletedIncomes, isEmpty);
      expect(find.text('ZZZ Shop rent'), findsOneWidget);
    });

    testWidgets('deletes it, updates the cards, and says so', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      await openDelete(tester, 1);

      await tester.tap(find.byKey(const Key('confirm-delete-income')));
      await tester.pumpAndSettle();

      expect(server.deletedIncomes, [1]);
      expect(find.text('ZZZ Shop rent'), findsNothing);
      expect(find.text('ZZZ Interest'), findsOneWidget);
      expect(find.text('ZZZ Shop rent deleted.'), findsOneWidget);
      expect(_inCard('card-other-income', 'Rs. 250.50'), findsOneWidget);
      expect(_inCard('card-other-income', '1 entry'), findsOneWidget);
      expect(_inCard('card-my-profit', 'Rs. 4,650.50'), findsOneWidget); // 6,400 + 250.50 - 2,000
    });

    testWidgets('keeps the entry and shows why when the server refuses', (tester) async {
      final server = _server();
      await _openIncome(tester, server);
      server.failMethods['DELETE'] = 403;
      await openDelete(tester, 1);

      await tester.tap(find.byKey(const Key('confirm-delete-income')));
      await tester.pumpAndSettle();

      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.text('ZZZ Shop rent'), findsOneWidget);
    });
  });

  testWidgets('expenses still work exactly as before on the other tab', (tester) async {
    final server = _server();
    await _show(tester, server);
    await tester.tap(find.byKey(const Key('tab-income')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('tab-expenses')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('expense-1')));
    await tester.pumpAndSettle();

    expect(find.text('Edit Expense'), findsOneWidget);
    expect(find.byKey(const Key('expense-category')), findsOneWidget);
  });
}
