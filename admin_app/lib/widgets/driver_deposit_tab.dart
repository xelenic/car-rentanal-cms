import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/driver_deposit.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'state_views.dart';

/// One driver's Deposit tab, one month at a time — current month to start,
/// stepped back and forward like the Expenses and Overview tabs' own month
/// bar. Mirrors the web panel's own Deposit tab: the cash-deposit breakdown
/// and any arrears loans against it. Read-only — converting a deficit into
/// an arrears loan and running payroll stay web-panel-only actions.
class DriverDepositTab extends StatefulWidget {
  const DriverDepositTab({super.key, required this.driverId});

  final int driverId;

  @override
  State<DriverDepositTab> createState() => _DriverDepositTabState();
}

class _DriverDepositTabState extends State<DriverDepositTab> with AutomaticKeepAliveClientMixin {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  DriverDeposit? _deposit;
  bool _loading = true;
  String? _error;

  static final _monthLabel = DateFormat('MMMM y');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deposit = await ApiClient.instance.fetchDriverDeposit(widget.driverId, year: _year, month: _month);
      if (mounted) setState(() => _deposit = deposit);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _stepMonth(int by) {
    final moved = DateTime(_year, _month + by);
    setState(() {
      _year = moved.year;
      _month = moved.month;
    });
    _load();
  }

  void _showSchedule(DriverArrearsLoan loan) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _ArrearsScheduleSheet(loan: loan),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: Row(
            children: [
              IconButton(
                key: const Key('driver-deposit-month-prev'),
                tooltip: 'Previous month',
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () => _stepMonth(-1),
              ),
              Expanded(
                child: Text(
                  _monthLabel.format(DateTime(_year, _month)),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
              ),
              IconButton(
                key: const Key('driver-deposit-month-next'),
                tooltip: 'Next month',
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () => _stepMonth(1),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    final deposit = _deposit!;

    if (!deposit.hasActivity) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: EmptyState(
                icon: Icons.savings_outlined,
                title: 'No deposit activity',
                message: 'Nothing recorded for ${deposit.periodLabel}.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('driver-deposit-body'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _DepositStatTile(
                    label: 'Total Hire Value',
                    value: formatRsShort(deposit.hireFullValueTotal),
                    icon: Icons.receipt_long_outlined,
                    color: const Color(0xFFB3810A),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _DepositStatTile(
                    label: 'Cash Payments',
                    value: formatRsShort(deposit.cashTotal),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF158F66),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _DepositStatTile(
                    label: 'Credit Payments',
                    value: formatRsShort(deposit.creditTotal),
                    icon: Icons.credit_card_outlined,
                    color: const Color(0xFF2A78D6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LineRow(label: 'Deposit Amount', value: formatRsExact(deposit.depositAmount)),
                  if (deposit.transferredTotal > 0)
                    _LineRow(
                      label: 'Already Transferred',
                      value: '-${formatRsExact(deposit.transferredTotal)}',
                      valueColor: AppColors.danger,
                    ),
                  const Divider(height: 18),
                  _LineRow(
                    label: 'Balance',
                    value: formatRsExact(deposit.balance),
                    emphasize: true,
                    valueColor: AppColors.primary,
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 18),
                  _LineRow(
                    label: 'Net Payable Salary',
                    value:
                        '${deposit.finalNetPayable < 0 ? '-' : ''}${formatRsExact(deposit.finalNetPayable.abs())}',
                    emphasize: true,
                    valueColor: deposit.finalNetPayable < 0 ? AppColors.danger : AppColors.success,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Net Salary Payable (${formatRsExact(deposit.netSalaryPayable)}) - Deposit Balance (${formatRsExact(deposit.balance)})',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          if (deposit.arrearsLoans.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Arrears Loans', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            const SizedBox(height: 8),
            for (final loan in deposit.arrearsLoans) ...[
              _ArrearsLoanCard(loan: loan, onTap: () => _showSchedule(loan)),
              const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _DepositStatTile extends StatelessWidget {
  const _DepositStatTile({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 9.5, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _LineRow extends StatelessWidget {
  const _LineRow({required this.label, required this.value, this.emphasize = false, this.valueColor});

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: emphasize ? 13.5 : 12.5,
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                color: emphasize ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: emphasize ? 15.5 : 13,
              fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrearsLoanCard extends StatelessWidget {
  const _ArrearsLoanCard({required this.loan, required this.onTap});

  final DriverArrearsLoan loan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(Icons.receipt_outlined, color: AppColors.primary),
        title: Text(formatRsExact(loan.amount), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(loan.deductionTypeLabel, style: const TextStyle(fontSize: 12)),
        trailing: Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}

class _ArrearsScheduleSheet extends StatelessWidget {
  const _ArrearsScheduleSheet({required this.loan});

  final DriverArrearsLoan loan;

  static final _monthLabel = DateFormat('MMMM y');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Arrears Loan Schedule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            '${loan.deductionTypeLabel} · ${formatRsExact(loan.amount)} total',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          for (final deduction in loan.deductions)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_monthLabel.format(DateTime(deduction.year, deduction.month)), style: const TextStyle(fontSize: 13)),
                  Text(formatRsExact(deduction.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
