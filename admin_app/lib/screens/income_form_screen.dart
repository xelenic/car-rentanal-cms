import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/my_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// The add / edit other-income form. Pops with the saved [OtherIncome].
class IncomeFormScreen extends StatefulWidget {
  const IncomeFormScreen({super.key, required this.initialDate, this.income});

  /// The date a new entry starts on (ignored when editing).
  final DateTime initialDate;

  /// The entry being edited; null when adding one.
  final OtherIncome? income;

  @override
  State<IncomeFormScreen> createState() => _IncomeFormScreenState();
}

class _IncomeFormScreenState extends State<IncomeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.income?.title ?? '');
  late final _amount = TextEditingController(text: widget.income == null ? '' : _plain(widget.income!.amount));
  late final _notes = TextEditingController(text: widget.income?.notes ?? '');

  late DateTime _date = widget.income?.date ?? widget.initialDate;

  bool _submitting = false;
  String? _error;

  static final _dateFormat = DateFormat('EEE, MMM d, y');

  bool get _editing => widget.income != null;

  /// 1500.0 -> "1500", 1500.5 -> "1500.5".
  static String _plain(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _notes.dispose();
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
      final saved = await ApiClient.instance.saveOtherIncome(
        id: widget.income?.id,
        title: _title.text.trim(),
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
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Income' : 'Add Income')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (_error != null) ...[
              Container(
                key: const Key('income-error'),
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
              key: const Key('income-title'),
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Income', hintText: 'e.g. Shop rent received'),
              validator: (value) => (value ?? '').trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              key: const Key('income-amount'),
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
              key: const Key('income-date'),
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
              key: const Key('income-notes'),
              controller: _notes,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              key: const Key('save-income'),
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : Text(_editing ? 'Save Changes' : 'Add Income'),
            ),
          ],
        ),
      ),
    );
  }
}
