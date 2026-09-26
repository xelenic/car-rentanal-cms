import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/my_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// The add / edit expense form. Pops with the saved [MyExpense].
class ExpenseFormScreen extends StatefulWidget {
  const ExpenseFormScreen({
    super.key,
    required this.categories,
    required this.canCreateCategory,
    required this.initialDate,
    this.expense,
  });

  /// What the category dropdown offers.
  final List<ExpenseCategory> categories;

  /// Whether "Add new category…" is offered in the dropdown.
  final bool canCreateCategory;

  /// The date a new expense starts on (ignored when editing).
  final DateTime initialDate;

  /// The expense being edited; null when adding one.
  final MyExpense? expense;

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.expense?.title ?? '');
  late final _amount = TextEditingController(text: widget.expense == null ? '' : _plain(widget.expense!.amount));
  late final _notes = TextEditingController(text: widget.expense?.notes ?? '');
  final _newCategory = TextEditingController();

  late String? _category = _initialCategory();
  late DateTime _date = widget.expense?.date ?? widget.initialDate;

  bool _submitting = false;
  String? _error;

  static final _dateFormat = DateFormat('EEE, MMM d, y');

  bool get _editing => widget.expense != null;
  bool get _addingCategory => _category == newExpenseCategoryOption;

  /// An edited expense keeps its category; a new one starts under "Others"
  /// (or the first category if there is no such one).
  String? _initialCategory() {
    final keys = widget.categories.map((c) => c.key);
    if (widget.expense != null) return widget.expense!.category;
    if (keys.contains('others')) return 'others';
    if (widget.categories.isNotEmpty) return widget.categories.first.key;
    return widget.canCreateCategory ? newExpenseCategoryOption : null;
  }

  /// 1500.0 -> "1500", 1500.5 -> "1500.5".
  static String _plain(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final saved = await ApiClient.instance.saveMyExpense(
        id: widget.expense?.id,
        title: _title.text.trim(),
        category: _category!,
        newCategory: _newCategory.text.trim(),
        amount: _amount.text.trim(),
        date: _date,
        notes: _notes.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // An edited expense's category may have been removed since; keep it selectable.
    final items = <DropdownMenuItem<String>>[
      for (final c in widget.categories) DropdownMenuItem(value: c.key, child: Text(c.name)),
      if (_editing && !widget.categories.any((c) => c.key == widget.expense!.category))
        DropdownMenuItem(value: widget.expense!.category, child: Text(widget.expense!.categoryName)),
      if (widget.canCreateCategory)
        const DropdownMenuItem(value: newExpenseCategoryOption, child: Text('＋ Add new category…')),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Expense' : 'Add Expense')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ...[
              Container(
                key: const Key('expense-error'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextFormField(
              key: const Key('expense-title'),
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Expense', hintText: 'e.g. Office rent'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              key: const Key('expense-category'),
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: items,
              onChanged: (value) => setState(() => _category = value),
              validator: (value) => value == null ? 'Pick a category' : null,
            ),
            if (_addingCategory) ...[
              const SizedBox(height: 14),
              TextFormField(
                key: const Key('new-category-name'),
                controller: _newCategory,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
                decoration: const InputDecoration(
                  labelText: 'New category name',
                  hintText: 'e.g. Bank charges',
                  helperText: 'Added to your categories when you save.',
                ),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Type a name for the new category' : null,
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('expense-amount'),
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Amount (Rs.)'),
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim());
                if (amount == null) return 'Enter an amount';
                if (amount <= 0) return 'Must be more than 0';
                return null;
              },
            ),
            const SizedBox(height: 14),
            InkWell(
              key: const Key('expense-date'),
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.event_rounded, size: 18),
                  helperText: "Counts toward this date's month.",
                ),
                child: Text(_dateFormat.format(_date), style: const TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('expense-notes'),
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('save-expense'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_editing ? 'Save Changes' : 'Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
