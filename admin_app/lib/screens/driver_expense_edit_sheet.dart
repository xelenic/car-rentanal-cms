import 'package:flutter/material.dart';

import '../models/driver_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// A small form — category and amount, the only two fields an admin can
/// correct on a driver-logged expense — opened as a bottom sheet from the
/// Expenses tab. Returns the updated [DriverExpense] on success.
class DriverExpenseEditSheet extends StatefulWidget {
  const DriverExpenseEditSheet({super.key, required this.expense});

  final DriverExpense expense;

  @override
  State<DriverExpenseEditSheet> createState() => _DriverExpenseEditSheetState();
}

class _DriverExpenseEditSheetState extends State<DriverExpenseEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late String _category = widget.expense.category;
  late final _amountController = TextEditingController(text: _formatAmount(widget.expense.amount));

  bool _saving = false;
  String? _error;

  static String _formatAmount(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await ApiClient.instance.updateDriverExpense(
        widget.expense.id,
        category: _category,
        amount: double.parse(_amountController.text.trim()),
      );
      if (mounted) Navigator.of(context).pop(updated);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Expense', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              key: const Key('edit-expense-category'),
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: [
                for (final entry in driverExpenseCategories.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: _saving ? null : (value) => setState(() => _category = value ?? _category),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('edit-expense-amount'),
              controller: _amountController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (Rs.)', border: OutlineInputBorder()),
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim());
                if (amount == null || amount <= 0) return 'Enter an amount greater than 0.';
                return null;
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('save-expense-edit'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
