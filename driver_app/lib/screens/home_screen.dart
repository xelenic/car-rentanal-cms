import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/driver.dart';
import '../models/driver_deposit_transfer.dart';
import '../models/driver_salary.dart';
import '../models/hire_page.dart';
import '../models/hire_tab.dart';
import '../models/tab_hires.dart';
import '../services/api_client.dart';
import '../services/background_tracking.dart';
import '../theme/app_theme.dart';
import '../widgets/tour_tabs.dart';
import '../widgets/initials_avatar.dart';
import 'deposit_transfer_screen.dart';
import 'login_screen.dart';
import 'salary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeDashboardData {
  final Driver driver;

  /// What each tour tab holds (its first hires, and how many there are).
  final Map<HireTab, TabHires> tabs;

  /// Every hire that counts — all but the cancelled ones.
  final int hireCount;
  final DriverSalary? salary;

  _HomeDashboardData({
    required this.driver,
    required this.tabs,
    required this.hireCount,
    required this.salary,
  });
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late Future<_HomeDashboardData> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
    // A hire may still be tracked from before the app was closed — bring the
    // background service back if the phone killed it meanwhile.
    unawaited(BackgroundTracking.ensureRunning());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(BackgroundTracking.ensureRunning());
    }
  }

  Future<_HomeDashboardData> _load() async {
    final results = await Future.wait([
      ApiClient.instance.fetchMe(),
      // Every open hire (Today and Scheduled are told apart on the phone by the
      // driver's own date), and just the first few completed / cancelled ones
      // with their exact totals — the rest is behind each tab's "More".
      ApiClient.instance.fetchHires(status: 'open'),
      ApiClient.instance.fetchHires(status: 'completed', perPage: kHomeTabLimit),
      ApiClient.instance.fetchHires(status: 'cancelled', perPage: kHomeTabLimit),
      // Only its counted total is used: how many hires there are that count.
      ApiClient.instance.fetchHires(perPage: 1),
      _loadSalarySafely(),
    ]);

    final open = results[1] as HirePage;

    // The server's own list of hires being tracked is the source of truth —
    // re-attach the background service to any it doesn't already cover.
    unawaited(BackgroundTracking.resume(open.items.where((h) => h.isTracking).map((h) => h.id)));

    return _HomeDashboardData(
      driver: results[0] as Driver,
      tabs: buildHomeTabs(open: open, completed: results[2] as HirePage, cancelled: results[3] as HirePage),
      hireCount: (results[4] as HirePage).countedTotal,
      salary: results[5] as DriverSalary?,
    );
  }

  // The current month's salary is a "nice to have" on the dashboard — if it
  // fails to load, the rest of the Home screen should still render.
  Future<DriverSalary?> _loadSalarySafely() async {
    try {
      return await ApiClient.instance.fetchSalary();
    } catch (_) {
      return null;
    }
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  /// Reloads after the driver comes back from a hire or a full list — what they
  /// did there (cancelled, completed, …) moves hires between tabs. The screen
  /// keeps showing what it has until the fresh data arrives.
  void _refreshQuietly() {
    if (mounted) unawaited(_refresh());
  }

  Future<void> _logout() async {
    // Signing out ends any background tracking first — the pings would only
    // start failing with 401s once the token is gone.
    await BackgroundTracking.stopAll();
    await ApiClient.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.neon,
          backgroundColor: AppColors.surface,
          onRefresh: _refresh,
          child: FutureBuilder<_HomeDashboardData>(
            future: _future,
            builder: (context, snapshot) {
              // While reloading, the previous data stays on screen (a snapshot
              // keeps it until the new future completes); only a first load —
              // with nothing to show yet — is a bare spinner.
              if (!snapshot.hasData && !snapshot.hasError) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.neon),
                );
              }

              if (snapshot.hasError) {
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 160),
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  _ProfileHeader(driver: data.driver, onLogout: _logout),
                  const SizedBox(height: 24),
                  _DashboardSummaryCard(hireCount: data.hireCount, salary: data.salary),
                  const SizedBox(height: 24),
                  TourTabs(tabs: data.tabs, onChanged: _refreshQuietly),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final Driver driver;
  final VoidCallback onLogout;

  const _ProfileHeader({required this.driver, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        InitialsAvatar(name: driver.name, size: 52),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome back',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                driver.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onLogout,
          icon: const Icon(Icons.logout, color: AppColors.textSecondary),
          tooltip: 'Logout',
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardSummaryCard extends StatelessWidget {
  final int hireCount;
  final DriverSalary? salary;

  const _DashboardSummaryCard({required this.hireCount, required this.salary});

  @override
  Widget build(BuildContext context) {
    final monthLabel = salary != null
        ? DateFormat.MMMM().format(DateTime(2000, salary!.month))
        : null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SalaryScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
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
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.onNeon.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.dashboard_outlined, color: AppColors.onNeon, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Overview',
                    style: TextStyle(
                      color: AppColors.onNeon,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  if (monthLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.onNeon.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        monthLabel,
                        style: const TextStyle(
                          color: AppColors.onNeon,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StatFigure(label: 'Total Hires', value: '$hireCount'),
                  ),
                  _StatDivider(),
                  Expanded(
                    child: _StatFigure(
                      label: 'Your Payment',
                      value: salary != null ? 'Rs. ${salary!.amountDue.toStringAsFixed(2)}' : '—',
                      emphasize: true,
                      subtitle: salary != null && salary!.isPaid ? 'Paid' : null,
                    ),
                  ),
                  _StatDivider(),
                  Expanded(
                    child: _StatFigure(
                      label: 'Total Expenses',
                      value: salary != null ? 'Rs. ${salary!.expensesTotal.toStringAsFixed(2)}' : '—',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: AppColors.onNeon.withValues(alpha: 0.18), height: 1),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _StatFigure(
                      label: 'Total Hire Value',
                      value: salary != null ? 'Rs. ${salary!.hireFullValueTotal.toStringAsFixed(2)}' : '—',
                      emphasize: true,
                    ),
                  ),
                  _StatDivider(),
                  Expanded(
                    child: _StatFigure(
                      label: 'Cash Payments',
                      value: salary != null ? 'Rs. ${salary!.cashHireFullValue.toStringAsFixed(2)}' : '—',
                    ),
                  ),
                  _StatDivider(),
                  Expanded(
                    child: _StatFigure(
                      label: 'Credit Payments',
                      value: salary != null ? 'Rs. ${salary!.creditHireFullValue.toStringAsFixed(2)}' : '—',
                    ),
                  ),
                ],
              ),
              if (salary != null) ...[
                const SizedBox(height: 16),
                _DepositButton(
                  onTap: () => _showDepositSummary(context, salary!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

void _showDepositSummary(BuildContext context, DriverSalary salary) {
  final monthLabel = DateFormat.MMMM().format(DateTime(2000, salary.month));

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => _DepositSummarySheet(salary: salary, monthLabel: monthLabel),
  );
}

class _DepositButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DepositButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onNeon.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppColors.onNeon, size: 16),
              SizedBox(width: 8),
              Text(
                'Deposit Summary',
                style: TextStyle(color: AppColors.onNeon, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DepositSummarySheet extends StatefulWidget {
  final DriverSalary salary;
  final String monthLabel;

  const _DepositSummarySheet({required this.salary, required this.monthLabel});

  @override
  State<_DepositSummarySheet> createState() => _DepositSummarySheetState();
}

class _DepositSummarySheetState extends State<_DepositSummarySheet> {
  late Future<List<DriverDepositTransfer>> _transfersFuture;

  @override
  void initState() {
    super.initState();
    _transfersFuture = _loadTransfers();
  }

  Future<List<DriverDepositTransfer>> _loadTransfers() {
    return ApiClient.instance.fetchDepositTransfers(
      year: widget.salary.year,
      month: widget.salary.month,
    );
  }

  Future<void> _openTransfer(double suggestedAmount) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DepositTransferScreen(
          year: widget.salary.year,
          month: widget.salary.month,
          monthLabel: widget.monthLabel,
          suggestedAmount: suggestedAmount,
        ),
      ),
    );

    if (saved == true && mounted) {
      setState(() => _transfersFuture = _loadTransfers());
    }
  }

  void _viewSlip(String url) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(url, fit: BoxFit.contain),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final salary = widget.salary;
    final deposit = salary.depositAmount;
    final yourPayment = salary.amountDue;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.neon.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.neon, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Deposit Summary · ${widget.monthLabel} ${salary.year}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _DepositRow(label: 'Total Hire Value', value: salary.hireFullValueTotal),
                const SizedBox(height: 10),
                _DepositRow(label: 'Cash Payments', value: salary.cashHireFullValue, muted: true),
                const SizedBox(height: 10),
                _DepositRow(label: 'Credit Payments', value: -salary.creditHireFullValue, muted: true),
                const SizedBox(height: 10),
                _DepositRow(label: 'Total Expenses', value: -salary.expensesTotal, muted: true),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                _DepositRow(label: 'Deposit Amount', value: deposit, highlight: true),
                const SizedBox(height: 10),
                const Text(
                  'Cash collected minus credit payments and this month\'s expenses — the amount to hand over to the company.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<DriverDepositTransfer>>(
                  future: _transfersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.neon),
                          ),
                        ),
                      );
                    }

                    final transfers = snapshot.data ?? const <DriverDepositTransfer>[];
                    final transferredTotal = transfers.fold<double>(0, (sum, t) => sum + t.amount);
                    final remaining = deposit - transferredTotal;
                    final netPayment = yourPayment - remaining;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (transferredTotal > 0) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: AppColors.border, height: 1),
                          ),
                          _DepositRow(label: 'Already Transferred', value: -transferredTotal, muted: true),
                          const SizedBox(height: 10),
                          _DepositRow(label: 'Remaining to Transfer', value: remaining, highlight: true),
                        ],
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: AppColors.border, height: 1),
                        ),
                        _DepositRow(label: 'Your Payment', value: yourPayment, highlight: remaining <= 0),
                        if (remaining > 0) ...[
                          const SizedBox(height: 10),
                          _DepositRow(label: 'Remaining to Transfer', value: -remaining, muted: true),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: AppColors.border, height: 1),
                          ),
                          _DepositRow(label: 'Net Payment', value: netPayment, highlight: true),
                          const SizedBox(height: 10),
                          const Text(
                            'Any deposit still owed is deducted from your salary payment.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                          ),
                        ],
                        if (transfers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Transfer History',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...transfers.map((transfer) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _TransferHistoryTile(
                                  transfer: transfer,
                                  onViewSlip: transfer.slipUrl != null
                                      ? () => _viewSlip(transfer.slipUrl!)
                                      : null,
                                ),
                              )),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Close'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: remaining > 0 ? () => _openTransfer(remaining) : null,
                                child: const Text('Transfer'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransferHistoryTile extends StatelessWidget {
  final DriverDepositTransfer transfer;
  final VoidCallback? onViewSlip;

  const _TransferHistoryTile({required this.transfer, this.onViewSlip});

  @override
  Widget build(BuildContext context) {
    final dateLabel = transfer.createdAt != null
        ? DateFormat('MMM d, y  h:mm a').format(transfer.createdAt!.toLocal())
        : null;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onViewSlip,
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: transfer.slipUrl != null
                  ? Image.network(
                      transfer.slipUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _slipFallback(),
                    )
                  : _slipFallback(),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rs. ${transfer.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (dateLabel != null)
                  Text(
                    dateLabel,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
          if (onViewSlip != null)
            const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
        ],
      ),
    );
  }

  Widget _slipFallback() {
    return Container(
      width: 40,
      height: 40,
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(Icons.receipt_long, color: AppColors.textMuted, size: 18),
    );
  }
}

class _DepositRow extends StatelessWidget {
  final String label;
  final double value;
  final bool muted;
  final bool highlight;

  const _DepositRow({
    required this.label,
    required this.value,
    this.muted = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final isNegative = value < 0;
    final color = highlight
        ? (isNegative ? Colors.redAccent : AppColors.neon)
        : (muted ? AppColors.textSecondary : AppColors.textPrimary);
    final sign = isNegative ? '-' : '';

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: highlight ? 14 : 13,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
        Text(
          '${sign}Rs. ${value.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: highlight ? 18 : 13,
            fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppColors.onNeon.withValues(alpha: 0.18),
    );
  }
}

class _StatFigure extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  final String? subtitle;

  const _StatFigure({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: AppColors.onNeon,
              fontWeight: FontWeight.w900,
              fontSize: emphasize ? 22 : 18,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            color: AppColors.onNeon.withValues(alpha: 0.8),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.onNeon.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subtitle!,
              style: const TextStyle(
                color: AppColors.onNeon,
                fontSize: 9,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

