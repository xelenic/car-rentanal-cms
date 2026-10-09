double _number(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

/// One driver's Overview tab: one month's earnings — mirrors
/// Api\Admin\DriverController::summary()'s response, the same
/// DriverSalaryCalculator formula behind the web panel's driver page and the
/// admin app's own company-wide dashboard.
class DriverSummary {
  const DriverSummary({
    required this.year,
    required this.month,
    required this.periodLabel,
    required this.hireCount,
    required this.hireFullValueTotal,
    required this.ourHireValueTotal,
    required this.commissionTotal,
    required this.expensesTotal,
    required this.salaryPayable,
    this.payrollStatus,
  });

  final int year;
  final int month;
  final String periodLabel;

  final int hireCount;
  final double hireFullValueTotal;
  final double ourHireValueTotal;
  final double commissionTotal;
  final double expensesTotal;
  final double salaryPayable;

  /// null (not yet finalized), 'finalized', or 'paid'.
  final String? payrollStatus;

  factory DriverSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};

    return DriverSummary(
      year: json['year'] as int,
      month: json['month'] as int,
      periodLabel: json['period_label'] as String? ?? '',
      hireCount: (summary['hire_count'] as num?)?.toInt() ?? 0,
      hireFullValueTotal: _number(summary['hire_full_value_total']),
      ourHireValueTotal: _number(summary['our_hire_value_total']),
      commissionTotal: _number(summary['commission_total']),
      expensesTotal: _number(summary['expenses_total']),
      salaryPayable: _number(summary['salary_payable']),
      payrollStatus: json['payroll_status'] as String?,
    );
  }
}
