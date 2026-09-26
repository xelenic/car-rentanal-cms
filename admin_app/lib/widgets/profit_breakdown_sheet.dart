import 'package:flutter/material.dart';

import '../models/my_expense.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

/// "How is My Profit worked out": the month's profit from hires line by line,
/// plus other income, then the owner's own expenses by category, down to My
/// Profit — the same working as the web panel's "Full Calculation".
class ProfitBreakdownSheet extends StatelessWidget {
  const ProfitBreakdownSheet({super.key, required this.summary});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    final b = summary.breakdown;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Profit — ${summary.label}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
            ),
            const SizedBox(height: 14),
            _line('Total Our Hire Value', formatRsExact(b.ourHireValueTotal)),
            _line("Less: Drivers' Hire Expenses", '-${formatRsExact(b.expensesTotal)}', negative: true),
            _line('Less: Driver Salary (${b.salaryPercentage.toStringAsFixed(0)}%)', '-${formatRsExact(b.salaryTotal)}', negative: true),
            _line('Less: Leasing Installments', '-${formatRsExact(b.leasingInstallmentTotal)}', negative: true),
            _line('Less: Vehicle Repair Cost', '-${formatRsExact(b.repairCostTotal)}', negative: true),
            const Divider(height: 22),
            _line('Profit From Hires', formatRsExact(summary.profitBeforeExpenses), bold: true),
            _line(
              'Add: Other Income (${countOf(summary.otherIncomeCount, 'entry', 'entries')})',
              '+${formatRsExact(summary.otherIncomeTotal)}',
              positive: true,
            ),
            const SizedBox(height: 10),
            const Text('Less: My Expenses', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            if (summary.byCategory.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 10, top: 2),
                child: Text(
                  'None recorded for ${summary.label}.',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              )
            else
              for (final row in summary.byCategory)
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: _line(row.name, '-${formatRsExact(row.total)}', negative: true, small: true),
                ),
            Padding(
              padding: const EdgeInsets.only(left: 10),
              child: _line('Total My Expenses', '-${formatRsExact(summary.total)}', negative: true, small: true, bold: true),
            ),
            const Divider(height: 22),
            Row(
              children: [
                const Expanded(child: Text('My Profit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                Text(
                  formatRsExact(summary.myProfit),
                  key: const Key('breakdown-my-profit'),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: summary.myProfit < 0 ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Profit From Hires (${formatRsExact(summary.profitBeforeExpenses)}) '
              '+ Other Income (${formatRsExact(summary.otherIncomeTotal)}) '
              '− My Expenses (${formatRsExact(summary.total)}) = ${formatRsExact(summary.myProfit)}.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(
    String label,
    String value, {
    bool negative = false,
    bool positive = false,
    bool bold = false,
    bool small = false,
  }) {
    final size = small ? 12.5 : 13.5;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: size,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: small ? AppColors.textSecondary : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: size,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: negative ? AppColors.danger : (positive ? AppColors.success : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
