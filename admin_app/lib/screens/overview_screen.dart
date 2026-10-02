import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/dashboard_summary.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/period_dropdown.dart';
import '../widgets/state_views.dart';

/// The admin app's dashboard: the same six summary figures as the web
/// panel's own Dashboard, for one month (a year/month picker, defaulting to
/// the current month), plus a per-vehicle breakdown of those same figures.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late final DateTime _now = DateTime.now();
  late int _year = _now.year;
  late int _month = _now.month;

  DashboardSummary? _summary;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    try {
      final summary = await ApiClient.instance.fetchDashboard(year: _year, month: _month);
      if (!mounted) return;
      setState(() => _summary = summary);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setYear(int year) {
    if (year == _year) return;
    setState(() => _year = year);
    _load();
  }

  void _setMonth(int month) {
    if (month == _month) return;
    setState(() => _month = month);
    _load();
  }

  /// The last five years plus the current one — simple and always valid,
  /// unlike the driver app's picker there's no "only periods with data"
  /// signal available here to narrow it further.
  List<int> get _yearOptions => [for (var y = _now.year; y >= _now.year - 5; y--) y];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ErrorState(message: _error!, onRetry: _load);
    }

    final summary = _summary!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: PeriodDropdown(
                hint: 'Year',
                value: _year,
                items: _yearOptions,
                labelBuilder: (year) => '$year',
                onChanged: _setYear,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PeriodDropdown(
                hint: 'Month',
                value: _month,
                items: const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
                labelBuilder: (month) => DateFormat.MMMM().format(DateTime(2000, month)),
                onChanged: _setMonth,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryGrid(summary: summary),
        if (summary.vehicleCards.isNotEmpty) ...[
          const SizedBox(height: 24),
          const _SectionLabel(icon: Icons.directions_car_filled_rounded, label: 'Vehicle Cards'),
          const SizedBox(height: 12),
          for (final card in summary.vehicleCards) ...[
            _VehicleCardTile(card: card),
            const SizedBox(height: 10),
          ],
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}

/// The six summary cards, in the same order as the web panel's Dashboard.
class _SummaryGrid extends StatelessWidget {
  final DashboardSummary summary;

  const _SummaryGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cards = [
      _StatCardData(
        icon: Icons.receipt_long_outlined,
        label: 'Total Hire Value',
        value: summary.hireFullValueTotal,
        delta: summary.deltas['hire_full_value_total'],
        color: const Color(0xFFB3810A),
      ),
      _StatCardData(
        icon: Icons.account_balance_outlined,
        label: 'Our Hire Value',
        value: summary.ourHireValueTotal,
        delta: summary.deltas['our_hire_value_total'],
        color: const Color(0xFF2A78D6),
      ),
      _StatCardData(
        icon: Icons.percent_rounded,
        label: 'Total Commission',
        value: summary.commissionTotal,
        delta: summary.deltas['commission_total'],
        color: const Color(0xFF158F66),
      ),
      _StatCardData(
        icon: Icons.account_balance_wallet_outlined,
        label: 'Total Expenses',
        value: summary.expensesTotal,
        delta: summary.deltas['expenses_total'],
        color: AppColors.danger,
      ),
      _StatCardData(
        icon: Icons.payments_outlined,
        label: 'All Drivers Salary',
        value: summary.salaryTotal,
        delta: summary.deltas['salary_total'],
        color: const Color(0xFFC95A26),
      ),
      _StatCardData(
        icon: Icons.trending_up_rounded,
        label: 'Total Profit',
        value: summary.profitTotal,
        delta: summary.deltas['profit_total'],
        color: const Color(0xFFC2477A),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
      ),
      itemBuilder: (context, index) => _StatCard(data: cards[index]),
    );
  }
}

class _StatCardData {
  final IconData icon;
  final String label;
  final double value;
  final double? delta;
  final Color color;

  const _StatCardData({
    required this.icon,
    required this.label,
    required this.value,
    required this.delta,
    required this.color,
  });
}

class _StatCard extends StatelessWidget {
  final _StatCardData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(color: data.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
            alignment: Alignment.center,
            child: Icon(data.icon, color: data.color, size: 16),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              'Rs. ${data.value.toStringAsFixed(2)}',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 14.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            data.label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (data.delta != null) ...[
            const SizedBox(height: 4),
            _DeltaLabel(delta: data.delta!),
          ],
        ],
      ),
    );
  }
}

class _DeltaLabel extends StatelessWidget {
  final double delta;

  const _DeltaLabel({required this.delta});

  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (delta) {
      > 0 => (Icons.arrow_upward_rounded, AppColors.success, '${delta.toStringAsFixed(1)}%'),
      < 0 => (Icons.arrow_downward_rounded, AppColors.danger, '${delta.abs().toStringAsFixed(1)}%'),
      _ => (Icons.remove_rounded, AppColors.textMuted, 'No change'),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// One vehicle's six-figure breakdown — a compact 2-column grid under its
/// name and condition, mirroring the web dashboard's own Vehicle Cards.
class _VehicleCardTile extends StatelessWidget {
  final DashboardVehicleCard card;

  const _VehicleCardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Hire Value', card.hireFullValueTotal, Icons.receipt_long_outlined),
      ('Our Hire Value', card.ourHireValueTotal, Icons.account_balance_outlined),
      ('Commission', card.commissionTotal, Icons.percent_rounded),
      ('Expenses', card.expensesTotal, Icons.account_balance_wallet_outlined),
      ('Salary', card.salaryTotal, Icons.payments_outlined),
      ('Profit', card.profitTotal, Icons.trending_up_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  card.model,
                  style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Pill(label: card.condition, color: AppColors.primary),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: metrics.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
            ),
            itemBuilder: (context, index) {
              final (label, value, icon) = metrics[index];
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5)),
                        Text(
                          'Rs. ${value.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 11.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
