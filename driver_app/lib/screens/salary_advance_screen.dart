import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/salary_advance_request.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Lets a driver request an advance on their salary and see the status of
/// their past requests (pending / approved / rejected by an admin).
class SalaryAdvanceScreen extends StatefulWidget {
  const SalaryAdvanceScreen({super.key});

  @override
  State<SalaryAdvanceScreen> createState() => _SalaryAdvanceScreenState();
}

class _SalaryAdvanceScreenState extends State<SalaryAdvanceScreen> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  bool _saving = false;
  bool _loadingHistory = true;
  String? _error;
  List<SalaryAdvanceRequest> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final history = await ApiClient.instance.fetchSalaryAdvances();
      if (!mounted) return;
      setState(() => _history = history);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ApiClient.instance.requestSalaryAdvance(
        amount: amount,
        reason: _reasonController.text.trim(),
      );
      if (!mounted) return;
      _amountController.clear();
      _reasonController.clear();
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salary advance request submitted.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salary Advance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request an Advance',
                  style: TextStyle(
                    color: AppColors.neon,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Reason (optional)',
                    hintText: 'Why do you need this advance?',
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onNeon,
                            ),
                          )
                        : const Text('Submit Request'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'History',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          if (_loadingHistory)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.neon),
              ),
            )
          else if (_history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No advance requests yet.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ..._history.map((advance) => _AdvanceTile(advance: advance)),
        ],
      ),
    );
  }
}

class _AdvanceTile extends StatelessWidget {
  final SalaryAdvanceRequest advance;

  const _AdvanceTile({required this.advance});

  Color get _statusColor {
    switch (advance.status) {
      case 'approved':
        return AppColors.neon;
      case 'rejected':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y  h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '\$${advance.amount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  advance.statusLabel,
                  style: TextStyle(color: _statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (advance.reason != null && advance.reason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              advance.reason!,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          if (advance.status != 'pending' && advance.adminNote != null && advance.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '"${advance.adminNote}"',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
          if (advance.createdAt != null) ...[
            const SizedBox(height: 6),
            Text(
              dateFormat.format(advance.createdAt!.toLocal()),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
