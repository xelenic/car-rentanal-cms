import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/admin_user.dart';
import '../models/my_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/profit_breakdown_sheet.dart';
import '../widgets/state_views.dart';
import 'expense_categories_screen.dart';
import 'expense_form_screen.dart';
import 'income_form_screen.dart';

/// The owner's own expenses and other income, a month at a time: My Profit
/// (the month's profit from hires plus other income, less the expenses) and
/// the totals up top, then the month's expenses or other income, one tab
/// each — with add, edit, delete and category management as the user's
/// permissions allow.
class MyExpensesScreen extends StatefulWidget {
  const MyExpensesScreen({super.key, required this.user});

  final AdminUser user;

  @override
  State<MyExpensesScreen> createState() => _MyExpensesScreenState();
}

enum _Tab { expenses, income }

class _MyExpensesScreenState extends State<MyExpensesScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  late int _year = DateTime.now().year;
  late int _month = DateTime.now().month;
  String? _category;
  _Tab _tab = _Tab.expenses;

  List<MyExpense> _expenses = [];
  List<OtherIncome> _incomes = [];
  ExpenseSummary? _summary;
  List<ExpenseCategory> _categories = [];
  List<int> _years = [];
  double _filteredTotal = 0;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = false;

  /// Bumped on every fresh load, so a slow answer for a month or filter that
  /// has since been changed can't overwrite a newer one.
  int _generation = 0;

  static final _shortDate = DateFormat('EEE, MMM d');

  AdminUser get _user => widget.user;
  bool get _searching => _searchController.text.trim().isNotEmpty;
  bool get _filtering => _searching || _category != null;
  bool get _onIncome => _tab == _Tab.income;
  bool get _hasActions => _user.canUpdateMyExpenses || _user.canDeleteMyExpenses;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// The categories for the filter chips and the form's dropdown. Not worth
  /// failing the screen over — the list still works without the chips.
  Future<void> _loadCategories() async {
    try {
      final categories = await ApiClient.instance.fetchExpenseCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Keep whatever we had.
    }
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    setState(() {
      if (!silent) _loading = true;
      _error = null;
    });

    try {
      if (_onIncome) {
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
      } else {
        final page = await ApiClient.instance.fetchMyExpenses(
          year: _year,
          month: _month,
          category: _category,
          search: _searchController.text.trim(),
        );
        if (!mounted || generation != _generation) return;
        setState(() {
          _expenses = page.expenses;
          _summary = page.summary;
          _years = page.years;
          _filteredTotal = page.filteredTotal;
          _hasMore = page.hasMore;
          _page = page.currentPage;
        });
      }
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
      if (_onIncome) {
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
      } else {
        final page = await ApiClient.instance.fetchMyExpenses(
          year: _year,
          month: _month,
          category: _category,
          search: _searchController.text.trim(),
          page: _page + 1,
        );
        if (!mounted || generation != _generation) return;
        final known = _expenses.map((e) => e.id).toSet();
        setState(() {
          _expenses = [..._expenses, ...page.expenses.where((e) => !known.contains(e.id))];
          _hasMore = page.hasMore;
          _page = page.currentPage;
        });
      }
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
    final years = {..._years, _year}.toList()..sort((a, b) => b.compareTo(a));
    final picked = await showModalBottomSheet<(int, int)>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _MonthPickerSheet(years: years, year: _year, month: _month),
    );
    if (picked != null && mounted) _showMonth(picked.$1, picked.$2);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    setState(() {}); // the clear button follows the text
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _setCategory(String? key) {
    if (key == _category) return;
    setState(() => _category = key);
    _load();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// New expenses start today when this month is on show, else on the 1st of the month being viewed.
  DateTime get _defaultDate {
    final now = DateTime.now();
    return now.year == _year && now.month == _month ? DateTime(now.year, now.month, now.day) : DateTime(_year, _month);
  }

  Future<void> _openForm({MyExpense? expense}) async {
    final saved = await Navigator.of(context).push<MyExpense>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(
          categories: _categories,
          canCreateCategory: _user.canCreateMyExpenses,
          initialDate: _defaultDate,
          expense: expense,
        ),
      ),
    );
    if (saved == null || !mounted) return;

    _snack('${saved.title} ${expense == null ? 'added' : 'updated'}.');
    // Straight to the month it landed in — otherwise an expense dated in
    // another month would seem to have vanished.
    _year = saved.date.year;
    _month = saved.date.month;
    _loadCategories(); // it may have brought a new category with it
    _load(silent: true);
  }

  Future<void> _confirmDelete(MyExpense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${expense.title}"?'),
        content: Text(
          '${formatRsExact(expense.amount)} comes off ${DateFormat('MMMM y').format(expense.date)}\'s '
          'expenses and back into My Profit. This can\'t be undone.',
        ),
        actions: [
          TextButton(
            key: const Key('keep-expense'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            key: const Key('confirm-delete-expense'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ApiClient.instance.deleteMyExpense(expense.id);
      if (!mounted) return;
      _snack('${expense.title} deleted.');
      _loadCategories();
      _load(silent: true);
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } catch (_) {
      if (mounted) _snack('Could not reach the server. Nothing was deleted.');
    }
  }

  Future<void> _manageCategories() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExpenseCategoriesScreen(user: _user)));
    if (!mounted) return;
    // Names and counts may have changed — on the chips and on the expenses.
    _loadCategories();
    _load(silent: true);
  }

  /// Switches between the expenses and the other income. A search or category
  /// belongs to one list, so it is dropped rather than carried to the other.
  void _setTab(_Tab tab) {
    if (tab == _tab) return;
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _tab = tab;
      _category = null;
    });
    _load();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Expenses'),
        actions: [
          if (_user.canManageExpenseCategories)
            IconButton(
              key: const Key('manage-categories'),
              tooltip: 'Categories',
              icon: const Icon(Icons.sell_outlined),
              onPressed: _manageCategories,
            ),
        ],
      ),
      floatingActionButton: _user.canCreateMyExpenses
          ? FloatingActionButton.extended(
              key: Key(_onIncome ? 'add-income' : 'add-expense'),
              onPressed: () => _onIncome ? _openIncomeForm() : _openForm(),
              icon: const Icon(Icons.add_rounded),
              label: Text(_onIncome ? 'Add Income' : 'Add Expense'),
            )
          : null,
      body: Column(
        children: [
          _MonthBar(
            label: _summary?.label ?? DateFormat('MMMM y').format(DateTime(_year, _month)),
            onPrevious: () => _stepMonth(-1),
            onNext: () => _stepMonth(1),
            onPick: _pickMonth,
          ),
          _TabSwitch(
            tab: _tab,
            expenseCount: _summary?.recordCount,
            incomeCount: _summary?.otherIncomeCount,
            onChanged: _setTab,
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
      onRefresh: () async {
        await _load(silent: true);
        _loadCategories();
      },
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
            _ProfitCard(summary: summary, onTap: _showProfitBreakdown),
            const SizedBox(height: 10),
            // The three that add up to My Profit, side by side and the same height.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatCard(
                      key: const Key('card-profit-before'),
                      label: 'Profit From Hires',
                      value: formatRsExact(summary.profitBeforeExpenses),
                      caption: "Dashboard's Total Profit",
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF2A78D6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      key: const Key('card-other-income'),
                      label: 'Other Income',
                      value: formatRsExact(summary.otherIncomeTotal),
                      caption: countOf(summary.otherIncomeCount, 'entry', 'entries'),
                      icon: Icons.payments_outlined,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatCard(
                      key: const Key('card-total'),
                      label: 'Total My Expenses',
                      value: formatRsExact(summary.total),
                      caption: countOf(summary.recordCount, 'record'),
                      icon: Icons.wallet_rounded,
                      color: const Color(0xFFC95A26),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              key: const Key('expense-search'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: _onIncome ? 'Search income or notes…' : 'Search expense or notes…',
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
            if (!_onIncome && _categories.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CategoryFilter(categories: _categories, selected: _category, onSelected: _setCategory),
            ],
            const SizedBox(height: 12),
            if ((_onIncome ? _incomes : _expenses).isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: EmptyState(
                  icon: _onIncome ? Icons.payments_outlined : Icons.wallet_rounded,
                  title: _onIncome
                      ? (_filtering ? 'No income matches' : 'No other income yet')
                      : (_filtering ? 'No expenses match' : 'No expenses yet'),
                  message: _filtering
                      ? (_onIncome ? 'Try a different search.' : 'Try a different search or category.')
                      : 'Nothing recorded for ${summary.label}.',
                ),
              )
            else ...[
              if (_onIncome)
                for (final income in _incomes) ...[
                  _EntryTile(
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
                ]
              else
                for (final expense in _expenses) ...[
                  _EntryTile(
                    keyPrefix: 'expense',
                    id: expense.id,
                    title: expense.title,
                    pillLabel: expense.categoryName,
                    dateLabel: _shortDate.format(expense.date),
                    notes: expense.notes,
                    amount: expense.amount,
                    onTap: _user.canUpdateMyExpenses ? () => _openForm(expense: expense) : null,
                    onEdit: _user.canUpdateMyExpenses ? () => _openForm(expense: expense) : null,
                    onDelete: _user.canDeleteMyExpenses ? () => _confirmDelete(expense) : null,
                    showMenu: _hasActions,
                  ),
                  const SizedBox(height: 8),
                ],
              if (_hasMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
                ),
              if (_filtering)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _onIncome
                        ? 'Total of the ${countOf(_incomes.length, 'entry', 'entries')} shown: ${formatRsExact(_filteredTotal)}'
                        : 'Total of the ${countOf(_expenses.length, 'expense')} shown: ${formatRsExact(_filteredTotal)}',
                    key: const Key('filtered-total'),
                    textAlign: TextAlign.end,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ‹ September 2026 › — steps a month at a time; tapping the name picks any month.
class _MonthBar extends StatelessWidget {
  const _MonthBar({required this.label, required this.onPrevious, required this.onNext, required this.onPick});

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            key: const Key('month-prev'),
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: onPrevious,
          ),
          Expanded(
            child: TextButton.icon(
              key: const Key('month-label'),
              onPressed: onPick,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              style: TextButton.styleFrom(foregroundColor: AppColors.textPrimary),
            ),
          ),
          IconButton(
            key: const Key('month-next'),
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: onNext,
          ),
        ],
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
                'Hires + other income − my expenses · tap for the working',
                style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 2,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.2),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            const SizedBox(height: 2),
            Text(caption, maxLines: 2, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.2)),
          ],
        ),
      ),
    );
  }
}

/// "All · Rent · Fuel · …" — one tap narrows the list to a category.
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({required this.categories, required this.selected, required this.onSelected});

  final List<ExpenseCategory> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [_chip('All', null), for (final category in categories) _chip(category.name, category.key)]),
    );
  }

  Widget _chip(String label, String? value) {
    final isSelected = selected == value;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        key: Key('category-filter-${value ?? 'all'}'),
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelected(value),
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        selectedColor: AppColors.surfaceElevated,
        backgroundColor: AppColors.surface,
        side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12.5,
        ),
      ),
    );
  }
}

/// One expense or one piece of other income: title, an optional category
/// pill, the date, notes and the amount — with an Edit / Delete menu when the
/// user may do either. [keyPrefix] ('expense' / 'income') names its keys.
class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.keyPrefix,
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.amount,
    required this.showMenu,
    this.pillLabel,
    this.notes,
    this.amountColor = AppColors.textPrimary,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final String keyPrefix;
  final int id;
  final String title;
  final String? pillLabel;
  final String dateLabel;
  final String? notes;
  final double amount;
  final Color amountColor;
  final bool showMenu;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: Key('$keyPrefix-$id'),
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
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (pillLabel != null) Pill(label: pillLabel!, color: AppColors.primary),
                        Text(dateLabel, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                    if (notes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: showMenu ? 10 : 0, right: showMenu ? 0 : 8),
                child: Text(
                  formatRsExact(amount),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: amountColor),
                ),
              ),
              if (showMenu)
                PopupMenuButton<String>(
                  key: Key('$keyPrefix-menu-$id'),
                  tooltip: 'More',
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                  onSelected: (value) => value == 'edit' ? onEdit?.call() : onDelete?.call(),
                  itemBuilder: (_) => [
                    if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Expenses 2 | Other Income 1" — the two lists the page switches between.
class _TabSwitch extends StatelessWidget {
  const _TabSwitch({required this.tab, required this.onChanged, this.expenseCount, this.incomeCount});

  final _Tab tab;
  final ValueChanged<_Tab> onChanged;
  final int? expenseCount;
  final int? incomeCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: _tab('tab-expenses', 'Expenses', expenseCount, _Tab.expenses),
          ),
          Expanded(
            child: _tab('tab-income', 'Other Income', incomeCount, _Tab.income),
          ),
        ],
      ),
    );
  }

  Widget _tab(String key, String label, int? count, _Tab value) {
    final selected = tab == value;
    final color = selected ? AppColors.primary : AppColors.textSecondary;

    return InkWell(
      key: Key(key),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: selected ? AppColors.primary : Colors.transparent, width: 2.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: color)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$count', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Year and month, in one sheet: pick a year, tap a month.
class _MonthPickerSheet extends StatefulWidget {
  const _MonthPickerSheet({required this.years, required this.year, required this.month});

  final List<int> years;
  final int year;
  final int month;

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year = widget.year;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose a month', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: const Key('picker-year'),
              initialValue: _year,
              decoration: const InputDecoration(labelText: 'Year'),
              items: [for (final y in widget.years) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: (value) => setState(() => _year = value ?? _year),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var month = 1; month <= 12; month++)
                  ChoiceChip(
                    key: Key('picker-month-$month'),
                    label: Text(DateFormat('MMM').format(DateTime(2000, month))),
                    selected: _year == widget.year && month == widget.month,
                    showCheckmark: false,
                    selectedColor: AppColors.surfaceElevated,
                    side: BorderSide(
                      color: _year == widget.year && month == widget.month ? AppColors.primary : AppColors.border,
                    ),
                    onSelected: (_) => Navigator.of(context).pop((_year, month)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
