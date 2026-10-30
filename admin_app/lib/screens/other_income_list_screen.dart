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
import 'income_form_screen.dart';

/// This month's other income: add, edit and delete, exactly as it worked
/// when this was one tab of a bigger page. Pushed from MyExpensesScreen's
/// section grid, with its own AppBar and FAB.
class OtherIncomeListScreen extends StatefulWidget {
  const OtherIncomeListScreen({super.key, required this.user, required this.initialYear, required this.initialMonth});

  final AdminUser user;
  final int initialYear;
  final int initialMonth;

  @override
  State<OtherIncomeListScreen> createState() => _OtherIncomeListScreenState();
}

class _OtherIncomeListScreenState extends State<OtherIncomeListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  late int _year = widget.initialYear;
  late int _month = widget.initialMonth;

  List<OtherIncome> _incomes = [];
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
      final page = await ApiClient.instance.fetchOtherIncomes(
        year: _year,
        month: _month,
        search: _searchController.text.trim(),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _incomes = page.incomes;
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
      final page = await ApiClient.instance.fetchOtherIncomes(
        year: _year,
        month: _month,
        search: _searchController.text.trim(),
        page: _page + 1,
      );
      if (!mounted || generation != _generation) return;
      final known = _incomes.map((e) => e.id).toSet();
      setState(() {
        _incomes = [..._incomes, ...page.incomes.where((e) => !known.contains(e.id))];
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

  /// New income starts today when this month is on show, else on the 1st of the month being viewed.
  DateTime get _defaultDate {
    final now = DateTime.now();
    return now.year == _year && now.month == _month ? DateTime(now.year, now.month, now.day) : DateTime(_year, _month);
  }

  Future<void> _openIncomeForm({OtherIncome? income}) async {
    final saved = await Navigator.of(context).push<OtherIncome>(
      MaterialPageRoute(builder: (_) => IncomeFormScreen(initialDate: _defaultDate, income: income)),
    );
    if (saved == null || !mounted) return;

    _snack('${saved.title} ${income == null ? 'added' : 'updated'}.');
    // Straight to the month it landed in, so it doesn't seem to have vanished.
    _year = saved.date.year;
    _month = saved.date.month;
    _load(silent: true);
  }

  Future<void> _confirmDeleteIncome(OtherIncome income) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${income.title}"?'),
        content: Text(
          '${formatRsExact(income.amount)} comes out of ${DateFormat('MMMM y').format(income.date)}\'s '
          'other income and out of My Profit. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            key: const Key('keep-income'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('confirm-delete-income'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.instance.deleteOtherIncome(income.id);
      if (!mounted) return;
      _snack('${income.title} deleted.');
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
      appBar: AppBar(title: const Text('Other Income')),
      floatingActionButton: _user.canCreateMyExpenses
          ? FloatingActionButton.extended(
              key: const Key('add-income'),
              onPressed: _openIncomeForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Income'),
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
            TextField(
              key: const Key('expense-search'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search income or notes…',
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
            if (_incomes.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: EmptyState(
                  icon: Icons.payments_outlined,
                  title: _searching ? 'No income matches' : 'No other income yet',
                  message: _searching ? 'Try a different search.' : 'Nothing recorded for ${summary.label}.',
                ),
              )
            else ...[
              for (final income in _incomes) ...[
                EntryTile(
                  keyPrefix: 'income',
                  id: income.id,
                  title: income.title,
                  dateLabel: _shortDate.format(income.date),
                  notes: income.notes,
                  amount: income.amount,
                  amountColor: AppColors.success,
                  onTap: _user.canUpdateMyExpenses ? () => _openIncomeForm(income: income) : null,
                  onEdit: _user.canUpdateMyExpenses ? () => _openIncomeForm(income: income) : null,
                  onDelete: _user.canDeleteMyExpenses ? () => _confirmDeleteIncome(income) : null,
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
                    'Total of the ${countOf(_incomes.length, 'entry', 'entries')} shown: ${formatRsExact(_filteredTotal)}',
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
