double _number(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// What the category dropdown submits for "Add new category…" — the server
/// then creates (or finds) a category from the accompanying name.
const newExpenseCategoryOption = '__new__';

/// A place to file expenses under. [key] never changes (renaming only changes
/// [name]), and is what an expense points at.
class ExpenseCategory {
  const ExpenseCategory({required this.id, required this.key, required this.name, this.expensesCount = 0});

  final int id;
  final String key;
  final String name;

  /// Expenses filed under it, all months — a category with any can't be deleted.
  final int expensesCount;

  bool get isInUse => expensesCount > 0;

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] as int,
      key: json['key'] as String? ?? '',
      name: json['name'] as String? ?? '',
      expensesCount: _int(json['expenses_count']),
    );
  }
}

/// One of the owner's own expenses — mirrors Api\Admin\MyExpenseResource.
class MyExpense {
  const MyExpense({
    required this.id,
    required this.title,
    required this.category,
    required this.categoryName,
    required this.amount,
    required this.date,
    this.notes,
  });

  final int id;
  final String title;

  /// The category's key.
  final String category;
  final String categoryName;
  final double amount;

  /// A calendar date (no time, no zone).
  final DateTime date;
  final String? notes;

  factory MyExpense.fromJson(Map<String, dynamic> json) {
    final notes = json['notes'] as String?;
    return MyExpense(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      categoryName: json['category_name'] as String? ?? '',
      amount: _number(json['amount']),
      date: parseCalendarDate(json['expense_date'] as String?),
      notes: notes != null && notes.trim().isNotEmpty ? notes : null,
    );
  }
}

/// "2026-09-12" -> that day, at local midnight — never shifted by a time zone.
DateTime parseCalendarDate(String? value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value ?? '');
  if (match == null) return DateTime.now();
  return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
}

/// A day as the API wants it: "2026-09-12".
String formatCalendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// What one category cost in the month.
class CategoryTotal {
  const CategoryTotal({required this.key, required this.name, required this.total});

  final String key;
  final String name;
  final double total;

  factory CategoryTotal.fromJson(Map<String, dynamic> json) => CategoryTotal(
        key: json['key'] as String? ?? '',
        name: json['name'] as String? ?? '',
        total: _number(json['total']),
      );
}

/// The working behind the month's profit — the lines of the "how is this
/// worked out" sheet.
class ProfitBreakdown {
  const ProfitBreakdown({
    this.ourHireValueTotal = 0,
    this.expensesTotal = 0,
    this.netBeforeSalary = 0,
    this.salaryPercentage = 0,
    this.salaryTotal = 0,
    this.leasingInstallmentTotal = 0,
    this.repairCostTotal = 0,
    this.profitTotal = 0,
  });

  final double ourHireValueTotal;

  /// What drivers logged as hire expenses (not the owner's own).
  final double expensesTotal;
  final double netBeforeSalary;
  final double salaryPercentage;
  final double salaryTotal;
  final double leasingInstallmentTotal;
  final double repairCostTotal;

  /// The profit before the owner's own expenses.
  final double profitTotal;

  factory ProfitBreakdown.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ProfitBreakdown();
    return ProfitBreakdown(
      ourHireValueTotal: _number(json['our_hire_value_total']),
      expensesTotal: _number(json['expenses_total']),
      netBeforeSalary: _number(json['net_before_salary']),
      salaryPercentage: _number(json['salary_percentage']),
      salaryTotal: _number(json['salary_total']),
      leasingInstallmentTotal: _number(json['leasing_installment_total']),
      repairCostTotal: _number(json['repair_cost_total']),
      profitTotal: _number(json['profit_total']),
    );
  }
}

/// The cards above a month's list. Always the whole month — a category or a
/// search only narrows the list.
class ExpenseSummary {
  const ExpenseSummary({
    required this.year,
    required this.month,
    required this.label,
    this.total = 0,
    this.recordCount = 0,
    this.profitBeforeExpenses = 0,
    this.myProfit = 0,
    this.byCategory = const [],
    this.breakdown = const ProfitBreakdown(),
  });

  final int year;
  final int month;
  final String label;
  final double total;
  final int recordCount;
  final double profitBeforeExpenses;
  final double myProfit;
  final List<CategoryTotal> byCategory;
  final ProfitBreakdown breakdown;

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSummary(
      year: _int(json['year']),
      month: _int(json['month']),
      label: json['label'] as String? ?? '',
      total: _number(json['total']),
      recordCount: _int(json['record_count']),
      profitBeforeExpenses: _number(json['profit_before_expenses']),
      myProfit: _number(json['my_profit']),
      byCategory: (json['by_category'] as List<dynamic>? ?? [])
          .map((e) => CategoryTotal.fromJson(e as Map<String, dynamic>))
          .toList(),
      breakdown: ProfitBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>?),
    );
  }
}

/// A page of a month's expenses from GET /admin/my-expenses.
class MyExpensePage {
  const MyExpensePage({
    required this.expenses,
    required this.currentPage,
    required this.lastPage,
    required this.summary,
    required this.filteredTotal,
    required this.years,
  });

  final List<MyExpense> expenses;
  final int currentPage;
  final int lastPage;
  final ExpenseSummary summary;

  /// The total of everything the current category/search matches (the whole month when nothing is filtered).
  final double filteredTotal;

  /// Years worth offering in the month picker.
  final List<int> years;

  bool get hasMore => currentPage < lastPage;

  factory MyExpensePage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>?;
    return MyExpensePage(
      expenses: (json['data'] as List<dynamic>? ?? []).map((e) => MyExpense.fromJson(e as Map<String, dynamic>)).toList(),
      currentPage: (meta?['current_page'] as int?) ?? 1,
      lastPage: (meta?['last_page'] as int?) ?? 1,
      summary: ExpenseSummary.fromJson(json['summary'] as Map<String, dynamic>? ?? const {}),
      filteredTotal: _number(json['filtered_total']),
      years: (json['years'] as List<dynamic>? ?? []).map((e) => _int(e)).toList(),
    );
  }
}
