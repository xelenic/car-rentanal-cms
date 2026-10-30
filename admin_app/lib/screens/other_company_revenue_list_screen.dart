import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_user.dart';
import '../models/my_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/my_expenses_shared.dart';
import '../widgets/state_views.dart';
import 'revenue_form_screen.dart';

/// This month's revenue from other rental companies: add, edit and delete,
/// exactly as it worked when this was one tab of a bigger page. Pushed from
/// MyExpensesScreen's section grid, with its own AppBar and FAB.
class OtherCompanyRevenueListScreen extends StatefulWidget {
  const OtherCompanyRevenueListScreen({
    super.key,
    required this.user,
    required this.initialYear,
    required this.initialMonth,
  });

  final AdminUser user;
  final int initialYear;
  final int initialMonth;

  @override
  State<OtherCompanyRevenueListScreen> createState() => _OtherCompanyRevenueListScreenState();
}

class _OtherCompanyRevenueListScreenState extends State<OtherCompanyRevenueListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  late int _year = widget.initialYear;
  late int _month = widget.initialMonth;

  List<OtherCompanyRevenue> _revenues = [];
  ExpenseSummary? _summary;
  List<int> _years = [];
  double _filteredTotal = 0;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  /// Bumped on every fresh load, so a slow answer for a month that has since
  /// been changed can't overwrite a newer one.
  int _generation = 0;

  static final _shortDate = DateFormat('EEE, MMM d');

  AdminUser get _user => widget.user;
  bool get _searching => _searchController.text.trim().isNotEmpty;
  bool get _hasActions => _user.canUpdateMyExpenses || _user.canDeleteMyExpenses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    try {
      final page = await ApiClient.instance.fetchOtherCompanyRevenues(
        year: _year,
        month: _month,
        search: _searchController.text.trim(),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _revenues = page.revenues;
        _summary = page.summary;
        _years = page.years;
        _filteredTotal = page.filteredTotal;
        _hasMore = page.hasMore;
        _page = page.currentPage;
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final generation = _generation;
    setState(() => _loadingMore = true);

    try {
      final page = await ApiClient.instance.fetchOtherCompanyRevenues(
        year: _year,
        month: _month,
        search: _searchController.text.trim(),
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      final known = _revenues.map((e) => e.id).toSet();
      setState(() {
        _revenues = [..._revenues, ...page.revenues.where((e) => !known.contains(e.id))];
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } catch (_) {
      // Silent — scrolling to the end again retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
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

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    setState(() {}); // the clear button follows the text
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// New revenue starts today when this month is on show, else on the 1st of the month being viewed.
  DateTime get _defaultDate {
    final now = DateTime.now();
    return now.year == _year && now.month == _month ? DateTime(now.year, now.month, now.day) : DateTime(_year, _month);
  }

  Future<void> _openRevenueForm({OtherCompanyRevenue? revenue}) async {
    final saved = await Navigator.of(context).push<OtherCompanyRevenue>(
      MaterialPageRoute(builder: (_) => RevenueFormScreen(initialDate: _defaultDate, revenue: revenue)),
    );
    if (saved == null || !mounted) return;

    _snack('${saved.hire} ${revenue == null ? 'added' : 'updated'}.');
    // Straight to the month it landed in, so it doesn't seem to have vanished.
    _year = saved.date.year;
    _month = saved.date.month;
    _load(silent: true);
  }

  Future<void> _confirmDeleteRevenue(OtherCompanyRevenue revenue) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${revenue.hire}"?'),
        content: Text(
          '${formatRsExact(revenue.balance)} comes out of ${DateFormat('MMMM y').format(revenue.date)}\'s '
          'other company revenue and out of My Profit. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            key: const Key('keep-revenue'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('confirm-delete-revenue'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.instance.deleteOtherCompanyRevenue(revenue.id);
      if (!mounted) return;
      _snack('${revenue.hire} deleted.');
      _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Could not reach the server. Nothing was deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Other Company Revenue')),
      floatingActionButton: _user.canCreateMyExpenses
          ? FloatingActionButton.extended(
              key: const Key('add-revenue'),
              onPressed: _openRevenueForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Revenue'),
            )
          : null,
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 240) {
            _loadMore();
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
          children: [
            _RevenueSummaryCard(summary: summary),
            const SizedBox(height: 14),
            TextField(
              key: const Key('expense-search'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search hire, booking # or vehicle…',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searching
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _debounce?.cancel();
                          setState(() {});
                          _load();
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            if (_revenues.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: EmptyState(
                  icon: Icons.apartment_rounded,
                  title: _searching ? 'No revenue matches' : 'No revenue from other companies yet',
                  message: _searching ? 'Try a different search.' : 'Nothing recorded for ${summary.label}.',
                ),
              )
            else ...[
              for (final revenue in _revenues) ...[
                _RevenueTile(
                  revenue: revenue,
                  dateLabel: _shortDate.format(revenue.date),
                  onTap: _user.canUpdateMyExpenses ? () => _openRevenueForm(revenue: revenue) : null,
                  onEdit: _user.canUpdateMyExpenses ? () => _openRevenueForm(revenue: revenue) : null,
                  onDelete: _user.canDeleteMyExpenses ? () => _confirmDeleteRevenue(revenue) : null,
                  showMenu: _hasActions,
                ),
                const SizedBox(height: 8),
              ],
              if (_hasMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                ),
              if (_searching)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Balance total of the ${countOf(_revenues.length, 'entry', 'entries')} shown: ${formatRsExact(_filteredTotal)}',
                    key: const Key('filtered-total'),
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// This month's revenue totals, unaffected by search: the full invoiced
/// amount, the vehicle's share, and the balance (what actually counts toward
/// My Profit) across every entry in the month.
class _RevenueSummaryCard extends StatelessWidget {
  const _RevenueSummaryCard({required this.summary});

  final ExpenseSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('revenue-summary'),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${countOf(summary.otherCompanyRevenueCount, 'entry', 'entries')} this month',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _RevenueStat(
                    key: const Key('revenue-summary-full'),
                    label: 'Full Amount',
                    value: formatRsExact(summary.otherCompanyRevenueFullAmountTotal),
                  ),
                ),
                Expanded(
                  child: _RevenueStat(
                    key: const Key('revenue-summary-vehicle'),
                    label: 'Vehicle Amount',
                    value: formatRsExact(summary.otherCompanyRevenueVehicleAmountTotal),
                  ),
                ),
                Expanded(
                  child: _RevenueStat(
                    key: const Key('revenue-summary-balance'),
                    label: 'Balance',
                    value: formatRsExact(summary.otherCompanyRevenueTotal),
                    valueColor: summary.otherCompanyRevenueTotal < 0 ? AppColors.danger : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RevenueStat extends StatelessWidget {
  const _RevenueStat({super.key, required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, maxLines: 1, style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: valueColor ?? AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// One revenue entry from another rental company: hire, booking number and
/// vehicle, the balance as the headline figure (what counts toward My
/// Profit), a secondary line with the full/credited/vehicle amounts, and a
/// small clip icon when a bank slip is attached — with the same Edit /
/// Delete menu as the shared EntryTile.
class _RevenueTile extends StatelessWidget {
  const _RevenueTile({
    required this.revenue,
    required this.dateLabel,
    required this.showMenu,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final OtherCompanyRevenue revenue;
  final String dateLabel;
  final bool showMenu;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: Key('revenue-${revenue.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(revenue.hire, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Pill(label: revenue.bookingNumber, color: AppColors.primary),
                        Text(revenue.vehicle, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        Text(dateLabel, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                        if (revenue.slipUrl != null) Icon(Icons.attach_file_rounded, size: 14, color: AppColors.textMuted),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Full ${formatRsExact(revenue.fullAmount)} · Credited ${formatRsExact(revenue.creditedAmount)} · '
                      'Vehicle ${formatRsExact(revenue.vehicleAmount)}',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: showMenu ? 10 : 0, right: showMenu ? 0 : 8),
                child: Text(
                  formatRsExact(revenue.balance),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: revenue.balance < 0 ? AppColors.danger : AppColors.success,
                  ),
                ),
              ),
              if (showMenu)
                PopupMenuButton<String>(
                  key: Key('revenue-menu-${revenue.id}'),
                  tooltip: 'More',
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                  onSelected: (value) => value == 'edit' ? onEdit?.call() : onDelete?.call(),
                  itemBuilder: (_) => [
                    if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
