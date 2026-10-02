import 'package:admin_app/models/dashboard_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DashboardSummary.fromJson', () {
    test('reads the six summary figures, deltas and period', () {
      final summary = DashboardSummary.fromJson({
        'year': 2026,
        'month': 9,
        'period_label': 'September 2026',
        'summary': {
          'hire_full_value_total': 10000,
          'our_hire_value_total': 7000,
          'commission_total': 3000,
          'expenses_total': 500,
          'salary_total': 1300,
          'profit_total': 5200,
        },
        'deltas': {
          'hire_full_value_total': 20.0,
          'our_hire_value_total': null,
        },
        'vehicle_cards': [],
      });

      expect(summary.year, 2026);
      expect(summary.month, 9);
      expect(summary.periodLabel, 'September 2026');
      expect(summary.hireFullValueTotal, 10000);
      expect(summary.ourHireValueTotal, 7000);
      expect(summary.commissionTotal, 3000);
      expect(summary.expensesTotal, 500);
      expect(summary.salaryTotal, 1300);
      expect(summary.profitTotal, 5200);
      expect(summary.deltas['hire_full_value_total'], 20.0);
      expect(summary.deltas['our_hire_value_total'], isNull);
      expect(summary.vehicleCards, isEmpty);
    });

    test('reads each vehicle card', () {
      final summary = DashboardSummary.fromJson({
        'year': 2026,
        'month': 9,
        'period_label': 'September 2026',
        'summary': <String, dynamic>{},
        'deltas': <String, dynamic>{},
        'vehicle_cards': [
          {
            'id': 1,
            'model': 'ZZZ Prius',
            'condition': 'Good',
            'hire_full_value_total': 10000,
            'our_hire_value_total': 7000,
            'commission_total': 3000,
            'expenses_total': 500,
            'salary_total': 1300,
            'profit_total': 5200,
          },
        ],
      });

      final card = summary.vehicleCards.single;
      expect(card.id, 1);
      expect(card.model, 'ZZZ Prius');
      expect(card.condition, 'Good');
      expect(card.hireFullValueTotal, 10000);
      expect(card.profitTotal, 5200);
    });

    test('a number that arrives as text still reads correctly', () {
      final summary = DashboardSummary.fromJson({
        'year': 2026,
        'month': 9,
        'period_label': 'September 2026',
        'summary': {'hire_full_value_total': '10000.50'},
        'deltas': <String, dynamic>{},
        'vehicle_cards': [],
      });

      expect(summary.hireFullValueTotal, 10000.5);
    });
  });
}
