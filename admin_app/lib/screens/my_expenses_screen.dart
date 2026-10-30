import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_user.dart';
import '../models/my_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/my_expenses_shared.dart';
import '../widgets/profit_breakdown_sheet.dart';
import '../widgets/state_views.dart';
import 'expenses_list_screen.dart';
import 'other_company_revenue_list_screen.dart';
import 'other_income_list_screen.dart';

/// One grid item on this landing page — tapping it opens that section (its
/// own list, add/edit/delete and all) as a standalone page.
class _ExpensesSection {
  const _ExpensesSection({required this.key, required this.label, required this.icon, required this.color, required this.count});

  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final int? count;
}

/// The owner's own finances for a month: My Profit up top, then a grid menu
/// to the three sections that make it up — Expenses, Other Income and Other
/// Company Revenue — each its own standalone page, the same shortcut-grid
/// pattern a driver's page uses for its own sections. Pushed from
/// HomeScreen's shortcut grid, with its own AppBar.
class MyExpensesScreen extends StatefulWidget {
  const MyExpensesScreen({super.key, required this.user});

  final AdminUser user;

  @override
  State<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

class _MyExpensesScreenState extends State<MyExpensesScreen> {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  ExpenseSummary? _summary;
  List<int> _years = [];
  bool _loading = true;
  String? _error;

  /// Bumped on every fresh load, so a slow answer for a month that has since
  /// been changed can't overwrite a newer one.
  int _generation = 0;

  AdminUser get _user => widget.user;

  /// Built fresh on every build (not cached) so its colors always reflect
  /// whichever theme is active right now — see AppColors in theme/app_theme.dart.
  List<_ExpensesSection> get _sections => [
        _ExpensesSection(
          key: 'expenses',
          label: 'Expenses',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFFE11D48),
          count: _summary?.recordCount,
        ),
        _ExpensesSection(
          key: 'income',
          label: 'Other Income',
          icon: Icons.payments_outlined,
          color: AppColors.success,
          count: _summary?.otherIncomeCount,
        ),
        _ExpensesSection(
          key: 'revenue',
          label: 'Other Company Revenue',
          icon: Icons.apartment_rounded,
          color: const Color(0xFF0D9488),
          count: _summary?.otherCompanyRevenueCount,
        ),
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    try {
      // Every section's own fetch already bundles this month's summary and
      // the years available — no separate summary endpoint needed.
      final page = await ApiClient.instance.fetchMyExpenses(year: _year, month: _month);
      if (!mounted || generation != _generation) return;
      setState(() {
        _summary = page.summary;
        _years = page.years;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = 'Could not reach the server. Check your connection and try again.');
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  void _showMonth(int year, int month) {
    if (year == _year && month == _month) return;
    setState(() {
      _year = year;
      _month = month;
    });
    _load();
  }

  void _stepMonth(int by) {
    final moved = DateTime(_year, _month + by);
    _showMonth(moved.year, moved.month);
  }

  Future<void> _pickMonth() async {
    final picked = await pickMonth(context, years: _years, year: _year, month: _month);
    if (picked != null && mounted) _showMonth(picked.$1, picked.$2);
  }

  void _showProfitBreakdown() {
    final summary = _summary;
    if (summary == null) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => ProfitBreakdownSheet(summary: summary),
    );
  }

  Future<void> _open(_ExpensesSection section) async {
    final Widget page = switch (section.key) {
      'expenses' => ExpensesListScreen(user: _user, initialYear: _year, initialMonth: _month),
      'income' => OtherIncomeListScreen(user: _user, initialYear: _year, initialMonth: _month),
      'revenue' => OtherCompanyRevenueListScreen(user: _user, initialYear: _year, initialMonth: _month),
      _ => const SizedBox.shrink(),
    };

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    // Whatever changed in there (an add, edit or delete) may have moved My
    // Profit or the counts on these tiles.
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: Column(
        children: [
          MonthBar(
            label: _summary?.label ?? DateFormat('MMMM y').format(DateTime(_year, _month)),
            onPrevious: () => _stepMonth(-1),
            onNext: () => _stepMonth(1),
            onPick: _pickMonth,
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return RefreshIndicator(
        onRefresh: () => _load(silent: true),
        child: ErrorState(message: _error!, onRetry: _load),
      );
    }

    final summary = _summary!;

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          _ProfitCard(summary: summary, onTap: _showProfitBreakdown),
          const SizedBox(height: 18),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sections.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              final section = _sections[index];
              return _SectionCard(
                key: Key('section-${section.key}'),
                section: section,
                onTap: () => _open(section),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// One grid tile on this landing page — same look as a driver page's own
/// section cards, with a record-count caption under the label.
class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.section, required this.onTap});

  final _ExpensesSection section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: section.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(section.icon, color: section.color, size: 26),
              ),
              const SizedBox(height: 14),
              Text(
                section.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14.5),
              ),
              if (section.count != null) ...[
                const SizedBox(height: 3),
                Text(
                  countOf(section.count!, 'entry', 'entries'),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// My Profit — the number this page is for. Tapping it shows how it is worked out.
class _ProfitCard extends StatelessWidget {
  const _ProfitCard({required this.summary, required this.onTap});

  final ExpenseSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final loss = summary.myProfit < 0;

    return Card(
      key: const Key('card-my-profit'),
      color: AppColors.primary,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.savings_outlined, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'My Profit · ${summary.label}',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ),
                  Icon(Icons.info_outline_rounded, size: 18, color: Colors.white.withValues(alpha: 0.85)),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatRsExact(summary.myProfit),
                  key: const Key('my-profit-value'),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: loss ? const Color(0xFFFFC9C9) : Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Hires + other income + other company revenue − my expenses · tap for the working',
                style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MiniStat(
                      key: const Key('card-profit-before'),
                      label: 'Profit From Hires',
                      value: formatRsExact(summary.profitBeforeExpenses),
                      caption: "Dashboard's Total Profit",
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      key: const Key('card-other-income'),
                      label: 'Other Income',
                      value: formatRsExact(summary.otherIncomeTotal),
                      caption: countOf(summary.otherIncomeCount, 'entry', 'entries'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _MiniStat(
                      key: const Key('card-other-revenue'),
                      label: 'Other Company Revenue',
                      value: formatRsExact(summary.otherCompanyRevenueTotal),
                      caption: countOf(summary.otherCompanyRevenueCount, 'entry', 'entries'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniStat(
                      key: const Key('card-total'),
                      label: 'Total My Expenses',
                      value: formatRsExact(summary.total),
                      caption: countOf(summary.recordCount, 'record'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the four figures that add up to My Profit, shown inside its own
/// card in white-on-blue instead of as its own separate card.
class _MiniStat extends StatelessWidget {
  const _MiniStat({super.key, required this.label, required this.value, required this.caption});

  final String label;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 2,
          style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.75), height: 1.2),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Colors.white)),
        ),
        const SizedBox(height: 1),
        Text(
          caption,
          maxLines: 2,
          style: TextStyle(fontSize: 9.5, color: Colors.white.withValues(alpha: 0.65), height: 1.2),
        ),
      ],
    );
  }
}
