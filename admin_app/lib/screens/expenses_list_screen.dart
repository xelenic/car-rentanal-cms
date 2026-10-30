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
import 'expense_categories_screen.dart';
import 'expense_form_screen.dart';

/// This month's expenses: add, edit, delete and category management, exactly
/// as it worked when this was one tab of a bigger page. Pushed from
/// MyExpensesScreen's section grid, with its own AppBar and FAB.
class ExpensesListScreen extends StatefulWidget {
  const ExpensesListScreen({super.key, required this.user, required this.initialYear, required this.initialMonth});

  final AdminUser user;
  final int initialYear;
  final int initialMonth;

  @override
  State<ExpensesListScreen> createState() => _ExpensesListScreenState();
}

class _ExpensesListScreenState extends State<ExpensesListScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  late int _year = widget.initialYear;
  late int _month = widget.initialMonth;
  String? _category;

  List<MyExpense> _expenses = [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      floatingActionButton: _user.canCreateMyExpenses
          ? FloatingActionButton.extended(
              key: const Key('add-expense'),
              onPressed: _openForm,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Expense'),
            )
          : null,
      body: Column(
        children: [
          MonthBar(
            label: _summary?.label ?? DateFormat('MMMM y').format(DateTime(_year, _month)),
            onPrevious: () => _stepMonth(-1),
            onNext: () => _stepMonth(1),
            onPick: _pickMonth,
            onManageCategories: _user.canManageExpenseCategories ? _manageCategories : null,
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
            TextField(
              key: const Key('expense-search'),
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search expense or notes…',
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
            if (_categories.isNotEmpty) ...[
              const SizedBox(height: 10),
              _CategoryFilter(categories: _categories, selected: _category, onSelected: _setCategory),
            ],
            const SizedBox(height: 12),
            if (_expenses.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: EmptyState(
                  icon: Icons.wallet_rounded,
                  title: _filtering ? 'No expenses match' : 'No expenses yet',
                  message: _filtering ? 'Try a different search or category.' : 'Nothing recorded for ${summary.label}.',
                ),
              )
            else ...[
              for (final expense in _expenses) ...[
                EntryTile(
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
                    'Total of the ${countOf(_expenses.length, 'expense')} shown: ${formatRsExact(_filteredTotal)}',
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
