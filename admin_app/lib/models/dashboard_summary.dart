double _number(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

/// One vehicle's six summary figures for the period — mirrors one entry of
/// Api\Admin\DashboardController's vehicle_cards array.
class DashboardVehicleCard {
  const DashboardVehicleCard({
    required this.id,
    required this.model,
    required this.condition,
    required this.hireFullValueTotal,
    required this.ourHireValueTotal,
    required this.commissionTotal,
    required this.expensesTotal,
    required this.salaryTotal,
    required this.profitTotal,
  });

  final int id;
  final String model;
  final String condition;
  final double hireFullValueTotal;
  final double ourHireValueTotal;
  final double commissionTotal;
  final double expensesTotal;
  final double salaryTotal;
  final double profitTotal;

  factory DashboardVehicleCard.fromJson(Map<String, dynamic> json) {
    return DashboardVehicleCard(
      id: json['id'] as int,
      model: json['model'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      hireFullValueTotal: _number(json['hire_full_value_total']),
      ourHireValueTotal: _number(json['our_hire_value_total']),
      commissionTotal: _number(json['commission_total']),
      expensesTotal: _number(json['expenses_total']),
      salaryTotal: _number(json['salary_total']),
      profitTotal: _number(json['profit_total']),
    );
  }
}

/// The admin app's Overview page, for one month — mirrors
/// Api\Admin\DashboardController's response, the same figures (and the same
/// calculation services behind them) as the web panel's own Dashboard.
class DashboardSummary {
  const DashboardSummary({
    required this.year,
    required this.month,
    required this.periodLabel,
    required this.hireFullValueTotal,
    required this.ourHireValueTotal,
    required this.commissionTotal,
    required this.expensesTotal,
    required this.salaryTotal,
    required this.profitTotal,
    required this.deltas,
    required this.vehicleCards,
  });

  final int year;
  final int month;
  final String periodLabel;

  final double hireFullValueTotal;
  final double ourHireValueTotal;
  final double commissionTotal;
  final double expensesTotal;
  final double salaryTotal;
  final double profitTotal;

  /// Percent change vs. the previous month, keyed the same as the summary
  /// fields above (e.g. 'hire_full_value_total') — null means "not
  /// computable" (the driver app and web panel both render that as "New").
  final Map<String, double?> deltas;

  final List<DashboardVehicleCard> vehicleCards;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final summary = json['summary'] as Map<String, dynamic>? ?? const {};
    final rawDeltas = json['deltas'] as Map<String, dynamic>? ?? const {};

    return DashboardSummary(
      year: json['year'] as int,
      month: json['month'] as int,
      periodLabel: json['period_label'] as String? ?? '',
      hireFullValueTotal: _number(summary['hire_full_value_total']),
      ourHireValueTotal: _number(summary['our_hire_value_total']),
      commissionTotal: _number(summary['commission_total']),
      expensesTotal: _number(summary['expenses_total']),
      salaryTotal: _number(summary['salary_total']),
      profitTotal: _number(summary['profit_total']),
      deltas: rawDeltas.map((key, value) => MapEntry(key, value == null ? null : _number(value))),
      vehicleCards: (json['vehicle_cards'] as List<dynamic>? ?? [])
          .map((e) => DashboardVehicleCard.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
