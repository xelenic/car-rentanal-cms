import 'package:admin_app/models/admin_user.dart';
import 'package:admin_app/models/my_expense.dart';
import 'package:admin_app/util/format.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_server.dart';

void main() {
  group('MyExpense.fromJson', () {
    test('reads an expense', () {
      final expense = MyExpense.fromJson(expenseJson(
        id: 7,
        title: 'ZZZ Office rent',
        category: 'rent',
        categoryName: 'Rent',
        amount: 1500.5,
        date: '2026-09-12',
        notes: 'ZZZ note',
      ));

      expect(expense.id, 7);
      expect(expense.title, 'ZZZ Office rent');
      expect(expense.category, 'rent');
      expect(expense.categoryName, 'Rent');
      expect(expense.amount, 1500.5);
      expect(expense.date, DateTime(2026, 9, 12));
      expect(expense.notes, 'ZZZ note');
    });

    test('treats blank notes as none', () {
      expect(MyExpense.fromJson(expenseJson(id: 1, date: '2026-09-12', notes: '   ')).notes, isNull);
      expect(MyExpense.fromJson(expenseJson(id: 1, date: '2026-09-12')).notes, isNull);
    });

    test('takes an amount that arrives as text', () {
      expect(MyExpense.fromJson({...expenseJson(id: 1, date: '2026-09-12'), 'amount': '250.75'}).amount, 250.75);
    });
  });

  group('calendar dates', () {
    test('are read as that day, whatever the time zone', () {
      final date = parseCalendarDate('2026-09-12');

      expect(date, DateTime(2026, 9, 12));
      expect(date.isUtc, isFalse);
      expect(date.hour, 0);
    });

    test('ignore a time or offset after the day', () {
      expect(parseCalendarDate('2026-09-12T23:30:00+05:30'), DateTime(2026, 9, 12));
    });

    test('are written the way the API wants them', () {
      expect(formatCalendarDate(DateTime(2026, 9, 5)), '2026-09-05');
      expect(formatCalendarDate(DateTime(2026, 12, 31, 23, 59)), '2026-12-31');
    });

    test('survive a round trip', () {
      final day = DateTime(2026, 1, 31);

      expect(parseCalendarDate(formatCalendarDate(day)), day);
    });
  });

  test('ExpenseCategory reads its name, key and how many expenses use it', () {
    final used = ExpenseCategory.fromJson({'id': 3, 'key': 'rent', 'name': 'Rent', 'expenses_count': 2});
    final unused = ExpenseCategory.fromJson({'id': 4, 'key': 'fuel', 'name': 'Fuel'});

    expect(used.key, 'rent');
    expect(used.isInUse, isTrue);
    expect(unused.expensesCount, 0);
    expect(unused.isInUse, isFalse);
  });

  test('ExpenseSummary reads the cards and the working behind them', () {
    final summary = ExpenseSummary.fromJson({
      'year': 2026,
      'month': 9,
      'label': 'September 2026',
      'total': 2000,
      'record_count': 2,
      'profit_before_expenses': 6400,
      'my_profit': 4400,
      'by_category': [
        {'key': 'rent', 'name': 'Rent', 'total': 1500.5},
        {'key': 'fuel', 'name': 'Fuel', 'total': 499.5},
      ],
      'breakdown': {
        'our_hire_value_total': 8000,
        'expenses_total': 100,
        'net_before_salary': 7900,
        'salary_percentage': 20,
        'salary_total': 1580,
        'leasing_installment_total': 300,
        'repair_cost_total': 200,
        'profit_total': 5820,
      },
    });

    expect(summary.label, 'September 2026');
    expect(summary.total, 2000);
    expect(summary.recordCount, 2);
    expect(summary.myProfit, 4400);
    expect(summary.byCategory.map((c) => c.name), ['Rent', 'Fuel']);
    expect(summary.byCategory.first.total, 1500.5);
    expect(summary.breakdown.salaryPercentage, 20);
    expect(summary.breakdown.leasingInstallmentTotal, 300);
    expect(summary.breakdown.profitTotal, 5820);
  });

  test('ExpenseSummary copes with a bare answer', () {
    final summary = ExpenseSummary.fromJson({'year': 2026, 'month': 9, 'label': 'September 2026'});

    expect(summary.total, 0);
    expect(summary.byCategory, isEmpty);
    expect(summary.breakdown.profitTotal, 0);
  });

  test('MyExpensePage reads the list, paging, filtered total and years', () {
    final page = MyExpensePage.fromJson({
      'data': [expenseJson(id: 1, date: '2026-09-02')],
      'meta': {'current_page': 1, 'last_page': 3},
      'summary': {'year': 2026, 'month': 9, 'label': 'September 2026', 'total': 100},
      'filtered_total': 40.5,
      'years': [2026, 2025],
    });

    expect(page.expenses, hasLength(1));
    expect(page.hasMore, isTrue);
    expect(page.filteredTotal, 40.5);
    expect(page.years, [2026, 2025]);
    expect(page.summary.total, 100);
  });

  test('AdminUser reads what the user may do with expenses, defaulting to nothing for an older server', () {
    final newer = AdminUser.fromJson({
      'id': 1, 'name': 'A', 'email': 'a@x.test',
      'can_view_my_expenses': true, 'can_create_my_expenses': true, 'can_update_my_expenses': false, 'can_delete_my_expenses': true,
    });
    final older = AdminUser.fromJson({'id': 1, 'name': 'A', 'email': 'a@x.test'});

    expect(newer.canViewMyExpenses, isTrue);
    expect(newer.canUpdateMyExpenses, isFalse);
    expect(newer.canManageExpenseCategories, isTrue);
    expect(older.canViewMyExpenses, isFalse);
    expect(older.canManageExpenseCategories, isFalse);
  });

  group('formatRsExact', () {
    test('keeps the cents', () {
      expect(formatRsExact(1500.5), 'Rs. 1,500.50');
      expect(formatRsExact(0), 'Rs. 0.00');
      expect(formatRsExact(1234567.891), 'Rs. 1,234,567.89');
    });

    test('puts the minus sign before the currency', () {
      expect(formatRsExact(-1200), '-Rs. 1,200.00');
    });
  });
}
