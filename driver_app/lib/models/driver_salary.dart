/// A single scheduled installment (or the one-shot deduction) of an
/// [ArrearsLoan].
class ArrearsLoanDeduction {
  final int year;
  final int month;
  final double amount;

  ArrearsLoanDeduction({required this.year, required this.month, required this.amount});

  factory ArrearsLoanDeduction.fromJson(Map<String, dynamic> json) {
    return ArrearsLoanDeduction(
      year: json['year'] as int,
      month: json['month'] as int,
      amount: (json['amount'] as num).toDouble(),
    );
  }
}

/// A deficit (negative Net Payment) converted by an admin into a scheduled
/// deduction against future salary — either fully next month, or split
/// across several upcoming months. Mirrors `DriverArrearsLoan` on the
/// admin side.
class ArrearsLoan {
  final int id;
  final double amount;
  final String deductionType;
  final String deductionTypeLabel;
  final List<ArrearsLoanDeduction> deductions;
  final int? sourceYear;
  final int? sourceMonth;
  final DateTime? createdAt;

  ArrearsLoan({
    required this.id,
    required this.amount,
    required this.deductionType,
    required this.deductionTypeLabel,
    required this.deductions,
    this.sourceYear,
    this.sourceMonth,
    this.createdAt,
  });

  /// How much of this loan is still outstanding (deductions not yet
  /// scheduled to have been applied as of the given period).
  double outstandingAsOf({required int year, required int month}) {
    return deductions
        .where((d) => d.year > year || (d.year == year && d.month >= month))
        .fold(0.0, (total, d) => total + d.amount);
  }

  factory ArrearsLoan.fromJson(Map<String, dynamic> json) {
    final rawDeductions = json['deductions'] as List<dynamic>? ?? [];

    return ArrearsLoan(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      deductionType: json['deduction_type'] as String,
      deductionTypeLabel: json['deduction_type_label'] as String,
      deductions: rawDeductions
          .map((entry) => ArrearsLoanDeduction.fromJson(entry as Map<String, dynamic>))
          .toList(),
      sourceYear: json['source_year'] as int?,
      sourceMonth: json['source_month'] as int?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

/// The deposit cash-flow breakdown for the period: what the driver owes vs.
/// what they've already handed over, and the final deposit-adjusted payable
/// amount. Mirrors the admin panel's Deposit section exactly.
class DepositSummary {
  final double transferredTotal;
  final double balance;
  final double finalNetPayable;
  final double arrearsLoanTotal;
  final double settledNetPayable;
  final List<ArrearsLoan> arrearsLoans;

  DepositSummary({
    required this.transferredTotal,
    required this.balance,
    required this.finalNetPayable,
    required this.arrearsLoanTotal,
    required this.settledNetPayable,
    required this.arrearsLoans,
  });

  /// True once the admin has converted this period's shortfall into an
  /// Arrears Loan — the driver already "received" the loan, so there's
  /// nothing further owed for it in cash.
  bool get isSettledByLoan => finalNetPayable < 0 && arrearsLoanTotal > 0;

  factory DepositSummary.fromJson(Map<String, dynamic> json) {
    final rawLoans = json['arrears_loans'] as List<dynamic>? ?? [];
    final finalNetPayable = (json['final_net_payable'] as num? ?? 0).toDouble();
    final arrearsLoanTotal = (json['arrears_loan_total'] as num? ?? 0).toDouble();

    return DepositSummary(
      transferredTotal: (json['transferred_total'] as num? ?? 0).toDouble(),
      balance: (json['balance'] as num? ?? 0).toDouble(),
      finalNetPayable: finalNetPayable,
      arrearsLoanTotal: arrearsLoanTotal,
      settledNetPayable:
          (json['settled_net_payable'] as num? ?? finalNetPayable + arrearsLoanTotal).toDouble(),
      arrearsLoans:
          rawLoans.map((entry) => ArrearsLoan.fromJson(entry as Map<String, dynamic>)).toList(),
    );
  }
}

/// A driver's monthly salary breakdown: total "Our Hire Value" for the
/// month, minus deductible expenses (Highway, Foods, Room, Parking), with
/// the driver's salary being 20% of what's left.
class DriverSalary {
  final int year;
  final int month;
  final int hireCount;
  final double ourHireValueTotal;
  final double hireFullValueTotal;
  final Map<String, double> hireFullValueByPaymentType;
  final double expensesTotal;
  final Map<String, double> expensesByCategory;
  final double netBeforeSalary;
  final double salaryPercentage;
  final double salary;
  final double advanceDeductionTotal;
  final double carryoverDeductionTotal;
  final double arrearsDeductionTotal;
  final double netSalaryPayable;
  final bool isPaid;
  final double paidAmount;
  final DateTime? paidAt;
  final double amountDue;
  final DepositSummary deposit;

  DriverSalary({
    required this.year,
    required this.month,
    required this.hireCount,
    required this.ourHireValueTotal,
    required this.hireFullValueTotal,
    required this.hireFullValueByPaymentType,
    required this.expensesTotal,
    required this.expensesByCategory,
    required this.netBeforeSalary,
    required this.salaryPercentage,
    required this.salary,
    required this.advanceDeductionTotal,
    required this.carryoverDeductionTotal,
    required this.arrearsDeductionTotal,
    required this.netSalaryPayable,
    required this.isPaid,
    required this.paidAmount,
    required this.paidAt,
    required this.amountDue,
    required this.deposit,
  });

  double get cashHireFullValue => hireFullValueByPaymentType['cash'] ?? 0;

  double get creditHireFullValue => hireFullValueByPaymentType['credit'] ?? 0;

  /// Cash the driver is holding that should be handed over to the company:
  /// total hire value minus whatever was already settled by credit, minus
  /// expenses the driver already paid out of pocket this month.
  double get depositAmount => hireFullValueTotal - creditHireFullValue - expensesTotal;

  factory DriverSalary.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['expenses_by_category'] as Map<String, dynamic>;
    final rawPaymentTypes = json['hire_full_value_by_payment_type'] as Map<String, dynamic>? ?? {};
    final netSalaryPayable = (json['net_salary_payable'] as num? ?? json['salary'] as num).toDouble();
    final isPaid = json['is_paid'] as bool? ?? false;
    final rawDeposit = json['deposit'] as Map<String, dynamic>?;

    return DriverSalary(
      year: json['year'] as int,
      month: json['month'] as int,
      hireCount: json['hire_count'] as int,
      ourHireValueTotal: (json['our_hire_value_total'] as num).toDouble(),
      hireFullValueTotal: (json['hire_full_value_total'] as num? ?? 0).toDouble(),
      hireFullValueByPaymentType: rawPaymentTypes.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      expensesTotal: (json['expenses_total'] as num).toDouble(),
      expensesByCategory: rawCategories.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      ),
      netBeforeSalary: (json['net_before_salary'] as num).toDouble(),
      salaryPercentage: (json['salary_percentage'] as num).toDouble(),
      salary: (json['salary'] as num).toDouble(),
      advanceDeductionTotal: (json['advance_deduction_total'] as num? ?? 0).toDouble(),
      carryoverDeductionTotal: (json['carryover_deduction_total'] as num? ?? 0).toDouble(),
      arrearsDeductionTotal: (json['arrears_deduction_total'] as num? ?? 0).toDouble(),
      netSalaryPayable: netSalaryPayable,
      isPaid: isPaid,
      paidAmount: (json['paid_amount'] as num? ?? 0).toDouble(),
      paidAt: json['paid_at'] != null ? DateTime.tryParse(json['paid_at'] as String) : null,
      amountDue: (json['amount_due'] as num? ?? (isPaid ? 0 : netSalaryPayable)).toDouble(),
      deposit: rawDeposit != null
          ? DepositSummary.fromJson(rawDeposit)
          : DepositSummary(
              transferredTotal: 0,
              balance: 0,
              finalNetPayable: netSalaryPayable,
              arrearsLoanTotal: 0,
              settledNetPayable: netSalaryPayable,
              arrearsLoans: [],
            ),
    );
  }
}
