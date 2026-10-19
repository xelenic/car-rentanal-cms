double _number(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

/// One deduction month of an arrears loan's repayment schedule.
class DriverArrearsLoanDeduction {
  const DriverArrearsLoanDeduction({required this.year, required this.month, required this.amount});

  final int year;
  final int month;
  final double amount;

  factory DriverArrearsLoanDeduction.fromJson(Map<String, dynamic> json) {
    return DriverArrearsLoanDeduction(
      year: json['year'] as int,
      month: json['month'] as int,
      amount: _number(json['amount']),
    );
  }
}

/// A deficit from an earlier month, converted into a loan deducted from
/// future salary — mirrors App\Models\DriverArrearsLoan.
class DriverArrearsLoan {
  const DriverArrearsLoan({
    required this.id,
    required this.amount,
    required this.deductionType,
    required this.deductionTypeLabel,
    this.deductions = const [],
  });

  final int id;
  final double amount;
  final String deductionType;
  final String deductionTypeLabel;
  final List<DriverArrearsLoanDeduction> deductions;

  factory DriverArrearsLoan.fromJson(Map<String, dynamic> json) {
    return DriverArrearsLoan(
      id: json['id'] as int,
      amount: _number(json['amount']),
      deductionType: json['deduction_type'] as String? ?? '',
      deductionTypeLabel: json['deduction_type_label'] as String? ?? '',
      deductions: (json['deductions'] as List<dynamic>? ?? [])
          .map((e) => DriverArrearsLoanDeduction.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// One driver's Deposit tab for a single month — the cash-deposit breakdown
/// and any arrears loans against it. Mirrors
/// Api\Admin\DriverController::deposit() and the web panel's own Deposit
/// tab (resources/views/admin/drivers/show.blade.php). Read-only here —
/// converting a deficit into an arrears loan and running payroll stay
/// web-panel-only actions.
class DriverDeposit {
  const DriverDeposit({
    required this.year,
    required this.month,
    required this.periodLabel,
    required this.hireFullValueTotal,
    required this.cashTotal,
    required this.creditTotal,
    required this.depositAmount,
    required this.transferredTotal,
    required this.balance,
    required this.netSalaryPayable,
    required this.finalNetPayable,
    required this.unresolvedDeficit,
    this.arrearsLoans = const [],
  });

  final int year;
  final int month;
  final String periodLabel;

  final double hireFullValueTotal;
  final double cashTotal;
  final double creditTotal;
  final double depositAmount;
  final double transferredTotal;
  final double balance;
  final double netSalaryPayable;
  final double finalNetPayable;
  final double unresolvedDeficit;
  final List<DriverArrearsLoan> arrearsLoans;

  /// There's any deposit or transfer activity at all for this period, worth
  /// showing a breakdown for rather than an empty state.
  bool get hasActivity => depositAmount != 0 || transferredTotal > 0;

  factory DriverDeposit.fromJson(Map<String, dynamic> json) {
    final deposit = json['deposit'] as Map<String, dynamic>? ?? const {};

    return DriverDeposit(
      year: json['year'] as int,
      month: json['month'] as int,
      periodLabel: json['period_label'] as String? ?? '',
      hireFullValueTotal: _number(deposit['hire_full_value_total']),
      cashTotal: _number(deposit['cash_total']),
      creditTotal: _number(deposit['credit_total']),
      depositAmount: _number(deposit['deposit_amount']),
      transferredTotal: _number(deposit['transferred_total']),
      balance: _number(deposit['balance']),
      netSalaryPayable: _number(deposit['net_salary_payable']),
      finalNetPayable: _number(deposit['final_net_payable']),
      unresolvedDeficit: _number(deposit['unresolved_deficit']),
      arrearsLoans: (json['arrears_loans'] as List<dynamic>? ?? [])
          .map((e) => DriverArrearsLoan.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
