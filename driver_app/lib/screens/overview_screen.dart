import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/available_periods.dart';
import '../models/driver_deposit_transfer.dart';
import '../models/driver_salary.dart';
import '../models/hire_page.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../widgets/period_dropdown.dart';
import 'deposit_transfer_screen.dart';

class _OverviewData {
  final int hireCount;
  final DriverSalary? salary;

  const _OverviewData({required this.hireCount, required this.salary});
}

/// The driver's full monthly overview, on its own page: total hires, this
/// month's pay, expenses and hire value — what used to sit as a card on Home.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  late final DateTime _now = DateTime.now();
  late int _year = _now.year;
  late int _month = _now.month;
  AvailablePeriods? _periods;

  late Future<_OverviewData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
    _loadPeriods();
  }

  Future<_OverviewData> _load() async {
    final results = await Future.wait([
      // Only its counted total is used: how many hires there are that count.
      // Scoped to the selected month — omitting year/month here would have
      // the server count the driver's entire hire history instead.
      ApiClient.instance.fetchHires(year: _year, month: _month, perPage: 1),
      _loadSalarySafely(),
    ]);

    return _OverviewData(
      hireCount: (results[0] as HirePage).countedTotal,
      salary: results[1] as DriverSalary?,
    );
  }

  // This month's salary is a "nice to have" here — if it fails to load, the
  // rest of the page (the hire count) should still render.
  Future<DriverSalary?> _loadSalarySafely() async {
    try {
      return await ApiClient.instance.fetchSalary(year: _year, month: _month);
    } catch (_) {
      return null;
    }
  }

  // Every period that has any hire at all, regardless of status — just
  // enough to populate the Year/Month pickers with periods worth looking at
  // (plus the current one, always offered even with nothing in it yet).
  Future<void> _loadPeriods() async {
    try {
      final periods = await ApiClient.instance.fetchAvailablePeriods();
      if (mounted) setState(() => _periods = periods);
    } catch (_) {
      // Without them the pickers offer just the current period — still usable.
    }
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  void _setYear(int? year) {
    if (year == null || year == _year) return;
    setState(() {
      _year = year;
      // A year change may not have this year's current month in it — snap to
      // its latest known month (or January) rather than risk an empty period.
      final months = _monthOptions(year);
      if (!months.contains(_month)) _month = months.isNotEmpty ? months.first : 1;
    });
    _refresh();
  }

  void _setMonth(int? month) {
    if (month == null || month == _month) return;
    setState(() => _month = month);
    _refresh();
  }

  List<int> get _yearOptions => {...?_periods?.years, _now.year}.toList()..sort((a, b) => b.compareTo(a));

  List<int> _monthOptions(int year) =>
      ({...?_periods?.monthsFor(year), if (year == _now.year) _now.month}.toList()..sort((a, b) => b.compareTo(a)));

  @override
  Widget build(BuildContext context) {
    final isCurrentPeriod = _year == _now.year && _month == _now.month;

    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
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
                    items: _monthOptions(_year),
                    labelBuilder: (month) => DateFormat.MMMM().format(DateTime(2000, month)),
                    onChanged: _setMonth,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.neon,
              backgroundColor: AppColors.surface,
              onRefresh: _refresh,
              child: FutureBuilder<_OverviewData>(
                future: _future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData && !snapshot.hasError) {
                    return Center(child: CircularProgressIndicator(color: AppColors.neon));
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 160),
                      children: [
                        Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    );
                  }

                  final data = snapshot.data!;
                  return _OverviewBody(
                    hireCount: data.hireCount,
                    salary: data.salary,
                    isCurrentPeriod: isCurrentPeriod,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The whole page below the app bar: a full-width hero (not a floating card
/// — it reads as a page section), then a grid of individual stat tiles, a
/// cash/credit split bar and the Deposit Summary button, so the page fills
/// the screen instead of leaving one box up top and blank space below.
class _OverviewBody extends StatefulWidget {
  final int hireCount;
  final DriverSalary? salary;
  final bool isCurrentPeriod;

  const _OverviewBody({required this.hireCount, required this.salary, required this.isCurrentPeriod});

  @override
  State<_OverviewBody> createState() => _OverviewBodyState();
}

class _OverviewBodyState extends State<_OverviewBody> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final salary = widget.salary;
    // Includes the year — once Overview can look at a different month, "May"
    // alone no longer says which year's May this is.
    final monthLabel = salary != null ? DateFormat.yMMMM().format(DateTime(salary.year, salary.month)) : null;

    // In the order the driver asked for: hires first, then the money figures
    // from the full hire value down to what they personally take home.
    final tiles = [
      _StatTile(
        icon: Icons.local_shipping_outlined,
        label: 'Total Hires',
        value: '${widget.hireCount}',
        color: AppColors.neon,
      ),
      _StatTile(
        icon: Icons.receipt_long_outlined,
        label: 'Total Hire Value',
        value: salary != null ? 'Rs. ${salary.hireFullValueTotal.toStringAsFixed(2)}' : '—',
        color: const Color(0xFFF59E0B),
      ),
      _StatTile(
        icon: Icons.account_balance_outlined,
        label: 'Company Hire Value',
        // What the company actually keeps before any deductions — the basis
        // the driver's salary percentage is calculated from.
        value: salary != null ? 'Rs. ${salary.ourHireValueTotal.toStringAsFixed(2)}' : '—',
        color: const Color(0xFF6366F1),
      ),
      _StatTile(
        icon: Icons.percent_rounded,
        label: 'Total Commission',
        // Full value minus what the company actually keeps — same definition
        // as the admin panel's own commission figures.
        value: salary != null ? 'Rs. ${(salary.hireFullValueTotal - salary.ourHireValueTotal).toStringAsFixed(2)}' : '—',
        color: const Color(0xFF2563EB),
      ),
      _StatTile(
        icon: Icons.wallet_outlined,
        label: 'Total Expenses',
        value: salary != null ? 'Rs. ${salary.expensesTotal.toStringAsFixed(2)}' : '—',
        color: AppColors.danger,
      ),
      _StatTile(
        icon: Icons.payments_outlined,
        label: 'Cash Payment',
        value: salary != null ? 'Rs. ${salary.cashHireFullValue.toStringAsFixed(2)}' : '—',
        color: const Color(0xFF0D9488),
      ),
      _StatTile(
        icon: Icons.credit_card_outlined,
        label: 'Credit Payment',
        value: salary != null ? 'Rs. ${salary.creditHireFullValue.toStringAsFixed(2)}' : '—',
        color: const Color(0xFF8B5CF6),
      ),
      _StatTile(
        icon: Icons.savings_outlined,
        label: salary != null ? 'My Salary (${salary.salaryPercentage.toStringAsFixed(0)}%)' : 'My Salary',
        value: salary != null ? 'Rs. ${salary.salary.toStringAsFixed(2)}' : '—',
        color: AppColors.success,
      ),
    ];

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _OverviewHero(
          hireCount: widget.hireCount,
          salary: salary,
          monthLabel: monthLabel,
          isCurrentPeriod: widget.isCurrentPeriod,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionLabel(icon: Icons.grid_view_rounded, label: 'Breakdown'),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: tiles.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemBuilder: (context, index) {
                  final start = index * 0.08;
                  final animation = CurvedAnimation(
                    parent: _controller,
                    curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
                  );

                  return AnimatedBuilder(
                    animation: animation,
                    builder: (context, child) => Opacity(
                      opacity: animation.value,
                      child: Transform.translate(offset: Offset(0, 18 * (1 - animation.value)), child: child),
                    ),
                    child: tiles[index],
                  );
                },
              ),
              if (salary != null && salary.hireFullValueTotal > 0) ...[
                const SizedBox(height: 24),
                const _SectionLabel(icon: Icons.pie_chart_outline_rounded, label: 'Cash vs Credit'),
                const SizedBox(height: 12),
                _PaymentSplitBar(salary: salary),
              ],
              if (salary != null) ...[
                const SizedBox(height: 24),
                _DepositButton(onTap: () => _showDepositSummary(context, salary)),
              ],
            ],
          ),
        ),
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
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.neon.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: AppColors.neon, size: 15),
        ),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
      ],
    );
  }
}

/// The page's header — full-bleed (no side margin, no rounded box, no
/// shadow) so it reads as a section of the page rather than a card floating
/// in it. Carries the driver's headline figure: what they're owed this month.
class _OverviewHero extends StatelessWidget {
  final int hireCount;
  final DriverSalary? salary;
  final String? monthLabel;
  final bool isCurrentPeriod;

  const _OverviewHero({
    required this.hireCount,
    required this.salary,
    required this.monthLabel,
    required this.isCurrentPeriod,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.neon, AppColors.neonDeep],
        ),
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
                child: Icon(Icons.dashboard_outlined, color: AppColors.onNeon, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                isCurrentPeriod ? 'This Month' : 'Monthly Overview',
                style: TextStyle(color: AppColors.onNeon, fontWeight: FontWeight.w700, fontSize: 15),
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
                    monthLabel!,
                    style: TextStyle(color: AppColors.onNeon, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Your Payment',
            style: TextStyle(color: AppColors.onNeon.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    salary != null ? 'Rs. ${salary!.amountDue.toStringAsFixed(2)}' : '—',
                    style: TextStyle(color: AppColors.onNeon, fontWeight: FontWeight.w900, fontSize: 34, height: 1.0),
                  ),
                ),
              ),
              if (salary != null && salary!.isPaid) ...[
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.onNeon.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Paid',
                      style: TextStyle(color: AppColors.onNeon, fontSize: 10.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hireCount == 0
                ? (isCurrentPeriod ? 'No hires yet this month' : 'No hires that month')
                : 'from ${countOf(hireCount, 'hire')}${isCurrentPeriod ? ' this month' : ''}',
            style: TextStyle(color: AppColors.onNeon.withValues(alpha: 0.8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// A short "N hire" / "N hires" count, matching the phrasing already used
/// elsewhere on the driver app's own stat cards.
String countOf(int count, String singular) => '$count ${count == 1 ? singular : '${singular}s'}';

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 16),
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// A proportional bar showing how this month's hire value split between cash
/// and credit — a quick, visual answer to "how much of this is cash in hand".
class _PaymentSplitBar extends StatelessWidget {
  final DriverSalary salary;

  const _PaymentSplitBar({required this.salary});

  @override
  Widget build(BuildContext context) {
    final total = salary.hireFullValueTotal;
    final cashFraction = total > 0 ? (salary.cashHireFullValue / total).clamp(0.0, 1.0) : 0.0;
    const cashColor = Color(0xFF0D9488);
    const creditColor = Color(0xFF8B5CF6);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (cashFraction > 0) Expanded(flex: (cashFraction * 1000).round(), child: Container(color: cashColor)),
                  if (cashFraction < 1)
                    Expanded(flex: ((1 - cashFraction) * 1000).round(), child: Container(color: creditColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _LegendDot(color: cashColor, label: 'Cash · ${(cashFraction * 100).toStringAsFixed(0)}%'),
              const SizedBox(width: 18),
              _LegendDot(color: creditColor, label: 'Credit · ${((1 - cashFraction) * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w600)),
      ],
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
      color: AppColors.neon,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, color: AppColors.onNeon, size: 18),
              SizedBox(width: 8),
              Text(
                'Deposit Summary',
                style: TextStyle(color: AppColors.onNeon, fontWeight: FontWeight.w700, fontSize: 14),
              ),
              SizedBox(width: 6),
              Icon(Icons.chevron_right, color: AppColors.onNeon, size: 18),
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
    return ApiClient.instance.fetchDepositTransfers(year: widget.salary.year, month: widget.salary.month);
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
        child: InteractiveViewer(child: Image.network(url, fit: BoxFit.contain)),
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
                    decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
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
                      child: Icon(Icons.account_balance_wallet_outlined, color: AppColors.neon, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Deposit Summary · ${widget.monthLabel} ${salary.year}',
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
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
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: AppColors.border, height: 1),
                ),
                _DepositRow(label: 'Deposit Amount', value: deposit, highlight: true),
                const SizedBox(height: 10),
                Text(
                  'Cash collected minus credit payments and this month\'s expenses — the amount to hand over to the company.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
                const SizedBox(height: 16),
                FutureBuilder<List<DriverDepositTransfer>>(
                  future: _transfersFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Padding(
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
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: AppColors.border, height: 1),
                          ),
                          _DepositRow(label: 'Already Transferred', value: -transferredTotal, muted: true),
                          const SizedBox(height: 10),
                          _DepositRow(label: 'Remaining to Transfer', value: remaining, highlight: true),
                        ],
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(color: AppColors.border, height: 1),
                        ),
                        _DepositRow(label: 'Your Payment', value: yourPayment, highlight: remaining <= 0),
                        if (remaining > 0) ...[
                          const SizedBox(height: 10),
                          _DepositRow(label: 'Remaining to Transfer', value: -remaining, muted: true),
                          Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Divider(color: AppColors.border, height: 1),
                          ),
                          _DepositRow(label: 'Net Payment', value: netPayment, highlight: true),
                          const SizedBox(height: 10),
                          Text(
                            'Any deposit still owed is deducted from your salary payment.',
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                          ),
                        ],
                        if (transfers.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Transfer History',
                            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                          const SizedBox(height: 8),
                          ...transfers.map((transfer) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _TransferHistoryTile(
                                  transfer: transfer,
                                  onViewSlip: transfer.slipUrl != null ? () => _viewSlip(transfer.slipUrl!) : null,
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
    final dateLabel = transfer.createdAt != null ? DateFormat('MMM d, y  h:mm a').format(transfer.createdAt!.toLocal()) : null;

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
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
                ),
                if (dateLabel != null)
                  Text(dateLabel, style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          if (onViewSlip != null) Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 18),
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
      child: Icon(Icons.receipt_long, color: AppColors.textMuted, size: 18),
    );
  }
}

class _DepositRow extends StatelessWidget {
  final String label;
  final double value;
  final bool muted;
  final bool highlight;

  const _DepositRow({required this.label, required this.value, this.muted = false, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final isNegative = value < 0;
    final color = highlight ? (isNegative ? Colors.redAccent : AppColors.neon) : (muted ? AppColors.textSecondary : AppColors.textPrimary);
    final sign = isNegative ? '-' : '';

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: color, fontSize: highlight ? 14 : 13, fontWeight: highlight ? FontWeight.w800 : FontWeight.w600),
          ),
        ),
        Text(
          '${sign}Rs. ${value.abs().toStringAsFixed(2)}',
          style: TextStyle(color: color, fontSize: highlight ? 18 : 13, fontWeight: highlight ? FontWeight.w800 : FontWeight.w700),
        ),
      ],
    );
  }
}

