import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_user.dart';
import '../models/driver_expense.dart';
import '../screens/driver_expense_edit_sheet.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'driver_expense_card.dart';
import 'state_views.dart';

/// One driver's logged expenses, one month at a time — current month to
/// start, stepped back and forward like the Hires tab's own month bar (see
/// HireHistoryTab). The total up top covers every expense the month
/// matched, not just the page shown.
class DriverExpensesTab extends StatefulWidget {
  const DriverExpensesTab({super.key, required this.driverId, this.user});

  final int driverId;
  final AdminUser? user;

  @override
  State<DriverExpensesTab> createState() => _DriverExpensesTabState();
}

class _DriverExpensesTabState extends State<DriverExpensesTab> with AutomaticKeepAliveClientMixin {
  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;

  List<DriverExpense> _expenses = [];
  DriverExpenseListSummary _summary = const DriverExpenseListSummary();
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  /// Bumped on every fresh load, so a slow answer for a month that has since
  /// been stepped away from can't overwrite a newer one.
  int _generation = 0;

  static final _monthLabel = DateFormat('MMMM y');

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final page = await ApiClient.instance.fetchDriverExpenses(widget.driverId, year: _year, month: _month);
      if (!mounted || generation != _generation) return;
      setState(() {
        _expenses = page.expenses;
        _summary = page.summary;
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
      final page = await ApiClient.instance.fetchDriverExpenses(
        widget.driverId,
        year: _year,
        month: _month,
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      final known = _expenses.map((e) => e.id).toSet();
      setState(() {
        _expenses = [..._expenses, ...page.expenses.where((e) => !known.contains(e.id))];
        _hasMore = page.hasMore;
        _page = page.currentPage;
      });
    } catch (_) {
      // Silent — scrolling to the end again retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
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

  double _round2(double value) => double.parse(value.toStringAsFixed(2));

  Future<void> _edit(DriverExpense expense) async {
    final updated = await showModalBottomSheet<DriverExpense>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DriverExpenseEditSheet(expense: expense),
    );
    if (updated == null || !mounted) return;

    setState(() {
      _expenses = [for (final e in _expenses) if (e.id == updated.id) updated else e];
      _summary = DriverExpenseListSummary(
        count: _summary.count,
        total: _round2(_summary.total - expense.amount + updated.amount),
      );
    });
  }

  Future<void> _delete(DriverExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this expense?'),
        content: Text('${expense.categoryLabel} · ${formatRsExact(expense.amount)}. This can\'t be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep it')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.instance.deleteDriverExpense(expense.id);
      if (!mounted) return;
      setState(() {
        _expenses = _expenses.where((e) => e.id != expense.id).toList();
        _summary = DriverExpenseListSummary(count: _summary.count - 1, total: _round2(_summary.total - expense.amount));
      });
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not reach the server. Nothing was deleted.')));
      }
    }
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
                key: const Key('driver-expenses-month-prev'),
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
                key: const Key('driver-expenses-month-next'),
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

    return RefreshIndicator(
      onRefresh: _load,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 240) {
            _loadMore();
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Text(
              '${countOf(_summary.count, 'expense')} · ${formatRsShort(_summary.total)} total',
              key: const Key('driver-expenses-summary'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            if (_expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No expenses this month',
                  message: 'Nothing recorded for ${_monthLabel.format(DateTime(_year, _month))}.',
                ),
              )
            else ...[
              for (final expense in _expenses) ...[
                DriverExpenseCard(
                  expense: expense,
                  onEdit: widget.user?.canUpdateHires ?? false ? () => _edit(expense) : null,
                  onDelete: widget.user?.canDeleteHires ?? false ? () => _delete(expense) : null,
                ),
                const SizedBox(height: 10),
              ],
              if (_hasMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
