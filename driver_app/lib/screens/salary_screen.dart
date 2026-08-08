import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/available_periods.dart';
import '../models/driver_salary.dart';
import '../models/hire_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/period_dropdown.dart';

/// Shows the driver's monthly salary: 20% of (Our Hire Value total minus
/// deductible expenses — Highway, Driver Foods, Room, Parking) for a
/// chosen year/month, defaulting to the most recent period with data.
class SalaryScreen extends StatefulWidget {
  const SalaryScreen({super.key});

  @override
  State<SalaryScreen> createState() => _SalaryScreenState();
}

class _SalaryScreenState extends State<SalaryScreen> {
  late Future<AvailablePeriods> _periodsFuture;
  Future<DriverSalary>? _salaryFuture;

  int? _year;
  int? _month;

  @override
  void initState() {
    super.initState();
    _periodsFuture = _loadPeriods();
  }

  Future<AvailablePeriods> _loadPeriods() async {
    final periods = await ApiClient.instance.fetchAvailablePeriods();

    if (periods.years.isNotEmpty) {
      final latestYear = periods.years.first;
      final months = periods.monthsFor(latestYear);
      _year = latestYear;
      _month = months.isNotEmpty ? months.first : null;
    }

    _salaryFuture = ApiClient.instance.fetchSalary(year: _year, month: _month);
    return periods;
  }

  void _setYear(AvailablePeriods periods, int? year) {
    setState(() {
      _year = year;
      _month = year != null ? periods.monthsFor(year).firstOrNull : null;
      _salaryFuture = ApiClient.instance.fetchSalary(year: _year, month: _month);
    });
  }

  void _setMonth(int? month) {
    setState(() {
      _month = month;
      _salaryFuture = ApiClient.instance.fetchSalary(year: _year, month: _month);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Salary')),
      body: FutureBuilder<AvailablePeriods>(
        future: _periodsFuture,
        builder: (context, periodsSnapshot) {
          if (periodsSnapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator(color: AppColors.neon));
          }

          if (periodsSnapshot.hasError) {
            return _ErrorText(message: periodsSnapshot.error.toString());
          }

          final periods = periodsSnapshot.data!;
          final months = periods.monthsFor(_year);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (periods.years.isNotEmpty)
                Row(
                  children: [
                    Expanded(
                      child: PeriodDropdown(
                        hint: 'Year',
                        value: _year,
                        items: periods.years,
                        labelBuilder: (year) => '$year',
                        onChanged: (year) => _setYear(periods, year),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PeriodDropdown(
                        hint: 'Month',
                        value: _month,
                        items: months,
                        labelBuilder: (month) => DateFormat.MMMM().format(DateTime(2000, month)),
                        onChanged: _year == null ? null : _setMonth,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              if (_salaryFuture == null)
                const _EmptyPeriodState()
              else
                FutureBuilder<DriverSalary>(
                  future: _salaryFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 60),
                        child: Center(child: CircularProgressIndicator(color: AppColors.neon)),
                      );
                    }

                    if (snapshot.hasError) {
                      return _ErrorText(message: snapshot.error.toString());
                    }

                    return _SalaryContent(salary: snapshot.data!);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _SalaryContent extends StatelessWidget {
  final DriverSalary salary;

  const _SalaryContent({required this.salary});

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat.MMMM().format(DateTime(2000, salary.month));
    final paidDateLabel = salary.paidAt != null ? DateFormat.yMMMd().format(salary.paidAt!.toLocal()) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.neon, AppColors.neonDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.neon.withValues(alpha: 0.28),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '$monthLabel ${salary.year} · ${salary.salaryPercentage.toStringAsFixed(0)}% Salary',
                      style: const TextStyle(
                        color: AppColors.onNeon,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (salary.isPaid)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.onNeon.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 12, color: AppColors.onNeon),
                          SizedBox(width: 4),
                          Text(
                            'PAID',
                            style: TextStyle(
                              color: AppColors.onNeon,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '\$${salary.amountDue.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.onNeon,
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'from ${salary.hireCount} hire${salary.hireCount == 1 ? '' : 's'} this month',
                style: const TextStyle(color: AppColors.onNeon, fontSize: 12),
              ),
              if (salary.isPaid) ...[
                const SizedBox(height: 2),
                Text(
                  'Paid \$${salary.paidAmount.toStringAsFixed(2)}${paidDateLabel != null ? ' on $paidDateLabel' : ''}',
                  style: const TextStyle(color: AppColors.onNeon, fontSize: 12),
                ),
              ] else if (salary.paidAmount > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '\$${salary.paidAmount.toStringAsFixed(2)} already paid'
                  '${paidDateLabel != null ? ' on $paidDateLabel' : ''} · '
                  '\$${salary.amountDue.toStringAsFixed(2)} new from more hires',
                  style: const TextStyle(color: AppColors.onNeon, fontSize: 12),
                ),
              ] else if (salary.advanceDeductionTotal > 0) ...[
                const SizedBox(height: 2),
                Text(
                  '\$${salary.salary.toStringAsFixed(2)} salary − \$${salary.advanceDeductionTotal.toStringAsFixed(2)} advance deduction',
                  style: const TextStyle(color: AppColors.onNeon, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Breakdown',
                style: TextStyle(
                  color: AppColors.neon,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              _BreakdownRow(label: 'Our Hire Value Total', value: salary.ourHireValueTotal),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: AppColors.border, height: 1),
              ),
              ...salary.expensesByCategory.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: _BreakdownRow(
                    label: '  ${HireExpense.labelFor(entry.key)}',
                    value: -entry.value,
                    muted: true,
                  ),
                ),
              ),
              _BreakdownRow(label: 'Total Expenses', value: -salary.expensesTotal),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: AppColors.border, height: 1),
              ),
              _BreakdownRow(label: 'Net Before Salary', value: salary.netBeforeSalary),
              const SizedBox(height: 4),
              _BreakdownRow(
                label: '${salary.salaryPercentage.toStringAsFixed(0)}% Driver Salary',
                value: salary.salary,
                highlight: salary.advanceDeductionTotal <= 0 &&
                    salary.carryoverDeductionTotal <= 0 &&
                    salary.arrearsDeductionTotal <= 0 &&
                    salary.paidAmount <= 0,
              ),
              if (salary.advanceDeductionTotal > 0 ||
                  salary.carryoverDeductionTotal > 0 ||
                  salary.arrearsDeductionTotal > 0) ...[
                if (salary.advanceDeductionTotal > 0) ...[
                  const SizedBox(height: 4),
                  _BreakdownRow(
                    label: 'Salary Advance Deduction',
                    value: -salary.advanceDeductionTotal,
                    muted: true,
                  ),
                ],
                if (salary.carryoverDeductionTotal > 0) ...[
                  const SizedBox(height: 4),
                  _BreakdownRow(
                    label: 'Carried Over from Previous Month',
                    value: -salary.carryoverDeductionTotal,
                    muted: true,
                  ),
                ],
                if (salary.arrearsDeductionTotal > 0) ...[
                  const SizedBox(height: 4),
                  _BreakdownRow(
                    label: 'Arrears Loan Deduction',
                    value: -salary.arrearsDeductionTotal,
                    muted: true,
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                _BreakdownRow(
                  label: 'Net Salary (without Deposit Deduction)',
                  value: salary.netSalaryPayable,
                  highlight: salary.paidAmount <= 0,
                ),
              ],
              if (salary.paidAmount > 0) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                _BreakdownRow(
                  label: 'Paid So Far',
                  value: salary.paidAmount,
                  highlight: salary.isPaid,
                  muted: !salary.isPaid,
                ),
                if (paidDateLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Paid on $paidDateLabel',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
                if (salary.amountDue > 0) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: AppColors.border, height: 1),
                  ),
                  _BreakdownRow(
                    label: 'Additional Amount Due',
                    value: salary.amountDue,
                    highlight: true,
                  ),
                ],
              ],
            ],
          ),
        ),
        if (salary.depositAmount != 0 || salary.deposit.transferredTotal > 0) ...[
          const SizedBox(height: 16),
          _DepositCard(salary: salary),
        ],
      ],
    );
  }
}

/// Mirrors the admin panel's Deposit section: the cash the driver is
/// holding vs. what they've already handed over, the resulting balance,
/// and the deposit-adjusted final payable amount. Also lists any Arrears
/// Loan created against this period's shortfall.
class _DepositCard extends StatelessWidget {
  final DriverSalary salary;

  const _DepositCard({required this.salary});

  @override
  Widget build(BuildContext context) {
    final deposit = salary.deposit;
    final finalNetPayable = deposit.finalNetPayable;
    // Once the admin has converted this shortfall into an Arrears Loan, the
    // driver has already effectively received that amount as a loan to
    // cover it — so what's actually still payable in cash settles to zero
    // instead of staying negative.
    final displayNetPayable = deposit.isSettledByLoan ? deposit.settledNetPayable : finalNetPayable;
    final finalColor = displayNetPayable < 0 ? AppColors.danger : AppColors.neon;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deposit',
            style: TextStyle(color: AppColors.neon, fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _BreakdownRow(label: 'Total Hire Value', value: salary.hireFullValueTotal, muted: true),
          const SizedBox(height: 6),
          _BreakdownRow(label: 'Cash Payments', value: salary.cashHireFullValue, muted: true),
          const SizedBox(height: 6),
          _BreakdownRow(label: 'Credit Payments', value: salary.creditHireFullValue, muted: true),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.border, height: 1),
          ),
          _BreakdownRow(label: 'Deposit Amount', value: salary.depositAmount, muted: true),
          if (deposit.transferredTotal > 0) ...[
            const SizedBox(height: 6),
            _BreakdownRow(label: 'Already Transferred', value: -deposit.transferredTotal, muted: true),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(color: AppColors.border, height: 1),
          ),
          _BreakdownRow(label: 'Balance', value: deposit.balance, highlight: true),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Divider(color: AppColors.border, height: 1),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Net Payable Salary',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
              Text(
                '${displayNetPayable < 0 ? '-' : ''}\$${displayNetPayable.abs().toStringAsFixed(2)}',
                style: TextStyle(color: finalColor, fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Net Salary (without Deposit Deduction) (\$${salary.netSalaryPayable.toStringAsFixed(2)}) '
            '- Deposit Balance (\$${deposit.balance.toStringAsFixed(2)}) '
            '= ${finalNetPayable < 0 ? '-' : ''}\$${finalNetPayable.abs().toStringAsFixed(2)}.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          if (deposit.isSettledByLoan) ...[
            const SizedBox(height: 4),
            Text(
              'Covered by an Arrears Loan of \$${deposit.arrearsLoanTotal.toStringAsFixed(2)} — '
              'settled, nothing further owed for this shortfall.',
              style: const TextStyle(color: AppColors.neon, fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
          if (deposit.arrearsLoans.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...deposit.arrearsLoans.map((loan) => _ArrearsLoanTile(loan: loan)),
          ],
        ],
      ),
    );
  }
}

class _ArrearsLoanTile extends StatelessWidget {
  final ArrearsLoan loan;

  const _ArrearsLoanTile({required this.loan});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showSchedule(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.receipt_long, size: 14, color: AppColors.neon),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Arrears Loan: \$${loan.amount.toStringAsFixed(2)} · ${loan.deductionTypeLabel}',
                style: const TextStyle(color: AppColors.neon, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSchedule(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loan.deductionTypeLabel,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${loan.amount.toStringAsFixed(2)} total',
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 14),
              ...loan.deductions.map(
                (d) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          DateFormat.yMMMM().format(DateTime(d.year, d.month)),
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                        ),
                      ),
                      Text(
                        '\$${d.amount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double value;
  final bool muted;
  final bool highlight;

  const _BreakdownRow({
    required this.label,
    required this.value,
    this.muted = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight
        ? AppColors.neon
        : (muted ? AppColors.textSecondary : AppColors.textPrimary);
    final sign = value < 0 ? '-' : '';

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: muted ? 12 : 13,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          '$sign\$${value.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: highlight ? 16 : (muted ? 12 : 13),
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyPeriodState extends StatelessWidget {
  const _EmptyPeriodState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.payments_outlined, size: 44, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'No hires recorded yet, so there\'s nothing to calculate.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;

  const _ErrorText({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 100),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
