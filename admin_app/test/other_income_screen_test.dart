import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/screens/other_income_list_screen.dart';
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

/// Two pieces of other income this month (1,750.50 together), one last month.
FakeServer _server() => FakeServer(
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
  await tester.pumpWidget(MaterialApp(
    theme: buildAdminAppTheme(),
    home: OtherIncomeListScreen(user: user ?? _user(), initialYear: _now.year, initialMonth: _now.month),
  ));
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

Iterable<Map<String, String>> _incomeQueries(FakeServer server) =>
    server.requestsTo('/api/admin/other-incomes').where((r) => r.method == 'GET').map((r) => r.url.queryParameters);

String _value(WidgetTester tester, String key) => tester.widget<TextFormField>(find.byKey(Key(key))).controller!.text;

void main() {
  group('the list', () {
    testWidgets('opens on this month and asks for it', (tester) async {
      final server = _server();
      await _show(tester, server);

      expect(_incomeQueries(server).first, {'year': '${_now.year}', 'month': '${_now.month}', 'page': '1'});
    });

    testWidgets('shows the month\'s income, newest first, with notes and amounts', (tester) async {
      await _show(tester, _server());

      expect(find.text('ZZZ Shop rent'), findsOneWidget);
      expect(find.text('ZZZ Interest'), findsOneWidget);
      expect(find.text('ZZZ Last month sale'), findsNothing);
      expect(find.text('ZZZ keys handed over'), findsOneWidget);
      expect(find.text('Rs. 1,500.00'), findsOneWidget);
      expect(find.text('Rs. 250.50'), findsOneWidget);
      expect(tester.getTopLeft(find.text('ZZZ Interest')).dy, lessThan(tester.getTopLeft(find.text('ZZZ Shop rent')).dy));
    });

    testWidgets('has its own search hint and no category chips', (tester) async {
      await _show(tester, _server());

      expect(find.byKey(const Key('category-filter-all')), findsNothing);
      expect(find.text('Search income or notes…'), findsOneWidget);
    });

    testWidgets('an empty month says so', (tester) async {
      await _show(tester, FakeServer());

      expect(find.text('No other income yet'), findsOneWidget);
      expect(find.text('Nothing recorded for $_thisMonthLabel.'), findsOneWidget);
    });

    testWidgets('a failed load shows the server\'s message and retries', (tester) async {
      final server = _server()..failWith = 500;
      await _show(tester, server);

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
      await _show(tester, server, settle: false);

      expect(_incomeQueries(server).map((q) => q['page']), ['1']);

      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await _quiet(tester, true);

      expect(_incomeQueries(server).map((q) => q['page']), ['1', '2']);
      expect(find.text('ZZZ income 1'), findsOneWidget);
    });
  });

  group('changing month', () {
    testWidgets('the arrows step the income', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.tap(find.byKey(const Key('month-prev')));
      await tester.pumpAndSettle();

      expect(_incomeQueries(server).last, {'year': '${_lastMonth.year}', 'month': '${_lastMonth.month}', 'page': '1'});
      expect(find.text('ZZZ Last month sale'), findsOneWidget);
      expect(find.text('ZZZ Shop rent'), findsNothing);
      expect(find.text(_lastMonthLabel), findsWidgets);
    });
  });

  group('searching income', () {
    testWidgets('narrows the list and says what the matches come to', (tester) async {
      final server = _server();
      await _show(tester, server);

      await tester.enterText(find.byKey(const Key('expense-search')), 'keys');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(_incomeQueries(server).last['search'], 'keys');
      expect(find.text('ZZZ Shop rent'), findsOneWidget);
      expect(find.text('ZZZ Interest'), findsNothing);
      expect(find.text('Total of the 1 entry shown: Rs. 1,500.00'), findsOneWidget);
    });

    testWidgets('says so when nothing matches', (tester) async {
      await _show(tester, _server());

      await tester.enterText(find.byKey(const Key('expense-search')), 'zebra');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(find.text('No income matches'), findsOneWidget);
      expect(find.text('Try a different search.'), findsOneWidget);
    });
  });

  group('adding income', () {
    testWidgets('is offered to someone who may create, hidden otherwise', (tester) async {
      await _show(tester, _server());
      expect(find.byKey(const Key('add-income')), findsOneWidget);
      expect(find.widgetWithText(FloatingActionButton, 'Add Income'), findsOneWidget);

      await _show(tester, _server(), user: _user(create: false));
      expect(find.byKey(const Key('add-income')), findsNothing);
    });

    testWidgets('opens a blank form, dated today', (tester) async {
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('add-income')));
      await tester.pumpAndSettle();

      expect(find.text('Add Income'), findsWidgets);
      expect(_value(tester, 'income-title'), '');
      expect(_value(tester, 'income-amount'), '');
      expect(find.text(DateFormat('EEE, MMM d, y').format(DateTime(_now.year, _now.month, _now.day))), findsOneWidget);
      expect(find.byKey(const Key('expense-category')), findsNothing); // income has no category
    });

    testWidgets('saves it and shows it in the list', (tester) async {
      final server = _server();
      await _show(tester, server);
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
    });

    testWidgets('takes income without notes', (tester) async {
      final server = _server();
      await _show(tester, server);
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
      await _show(tester, server);
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
      await _show(tester, server);
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
      await _show(tester, server);
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
      await _show(tester, server);
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
      await _show(tester, _server());

      await tester.tap(find.byKey(const Key('income-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Income'), findsOneWidget);
      expect(_value(tester, 'income-title'), 'ZZZ Shop rent');
      expect(_value(tester, 'income-amount'), '1500');
      expect(_value(tester, 'income-notes'), 'ZZZ keys handed over');
      expect(find.text(DateFormat('EEE, MMM d, y').format(DateTime(_now.year, _now.month, 2))), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Save Changes'), findsOneWidget);
    });

    testWidgets('saves the change to that entry', (tester) async {
      final server = _server();
      await _show(tester, server);
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
    });

    testWidgets('someone who may not edit cannot open one', (tester) async {
      await _show(tester, _server(), user: _user(update: false));

      await tester.tap(find.byKey(const Key('income-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit Income'), findsNothing);
    });

    testWidgets('the menu offers what the user may do', (tester) async {
      await _show(tester, _server(), user: _user(update: false));

      await tester.tap(find.byKey(const Key('income-menu-1')));
      await tester.pumpAndSettle();

      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('no menu at all for someone who may neither edit nor delete', (tester) async {
      await _show(tester, _server(), user: _user(update: false, delete: false));

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
      await _show(tester, server);

      await openDelete(tester, 1);

      expect(find.text('Delete "ZZZ Shop rent"?'), findsOneWidget);
      expect(find.textContaining('Rs. 1,500.00 comes out of $_thisMonthLabel'), findsOneWidget);
      expect(server.deletedIncomes, isEmpty);
    });

    testWidgets('"Keep it" changes nothing', (tester) async {
      final server = _server();
      await _show(tester, server);
      await openDelete(tester, 1);

      await tester.tap(find.byKey(const Key('keep-income')));
      await tester.pumpAndSettle();

      expect(server.deletedIncomes, isEmpty);
      expect(find.text('ZZZ Shop rent'), findsOneWidget);
    });

    testWidgets('deletes it and says so', (tester) async {
      final server = _server();
      await _show(tester, server);
      await openDelete(tester, 1);

      await tester.tap(find.byKey(const Key('confirm-delete-income')));
      await tester.pumpAndSettle();

      expect(server.deletedIncomes, [1]);
      expect(find.text('ZZZ Shop rent'), findsNothing);
      expect(find.text('ZZZ Interest'), findsOneWidget);
      expect(find.text('ZZZ Shop rent deleted.'), findsOneWidget);
    });

    testWidgets('keeps the entry and shows why when the server refuses', (tester) async {
      final server = _server();
      await _show(tester, server);
      server.failMethods['DELETE'] = 403;
      await openDelete(tester, 1);

      await tester.tap(find.byKey(const Key('confirm-delete-income')));
      await tester.pumpAndSettle();

      expect(find.text('The server said no.'), findsOneWidget);
      expect(find.text('ZZZ Shop rent'), findsOneWidget);
    });
  });
}
