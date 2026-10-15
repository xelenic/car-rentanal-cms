import 'package:flutter/material.dart';

import '../models/hire.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Records a payment against a credit hire's remaining balance — amount and
/// an optional note are the only inputs; the date is always today, set
/// server-side. Starts prefilled with the full balance, since settling the
/// whole thing is the common case; editable down for a partial payment.
/// Returns the updated [Hire] on success.
class ClaimPaymentSheet extends StatefulWidget {
  const ClaimPaymentSheet({super.key, required this.hireId, required this.balanceRemaining});

  final int hireId;
  final double balanceRemaining;

  @override
  State<ClaimPaymentSheet> createState() => _ClaimPaymentSheetState();
}

class _ClaimPaymentSheetState extends State<ClaimPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(text: _formatAmount(widget.balanceRemaining));
  final _notesController = TextEditingController();

  bool _saving = false;
  String? _error;

  static String _formatAmount(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : '$value';

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final hire = await ApiClient.instance.claimHirePayment(
        widget.hireId,
        amount: double.parse(_amountController.text.trim()),
        notes: _notesController.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(hire);
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
            const Text('Claim Payment', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 4),
            Text(
              'Starts filled with the full balance — edit it down to record a partial payment instead.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('claim-payment-amount'),
              controller: _amountController,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (Rs.)', border: OutlineInputBorder()),
              validator: (value) {
                final amount = double.tryParse((value ?? '').trim());
                if (amount == null || amount <= 0) return 'Enter an amount greater than 0.';
                if (amount > widget.balanceRemaining + 0.004) return 'Can\'t exceed the balance remaining.';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('claim-payment-notes'),
              controller: _notesController,
              enabled: !_saving,
              maxLength: 255,
              decoration: const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
            ),
            if (_error != null) ...[
              const SizedBox(height: 6),
              Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('save-claim-payment'),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      )
                    : const Text('Record Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
