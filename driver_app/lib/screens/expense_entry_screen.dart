import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/hire.dart';
import '../models/hire_expense.dart';
import '../services/api_client.dart';
import '../theme/app_theme.dart';

/// Generic "add an expense" screen used both by the hire detail quick
/// actions (Fuel, Highway, ...) and by the Options page's category tiles.
/// With a [hire], the entry and its history are scoped to that one hire;
/// without one, it's logged directly against the driver (still counts
/// toward the month's salary deduction) and history covers every entry in
/// that category. The receipt photo can be required or optional depending
/// on the category.
class ExpenseEntryScreen extends StatefulWidget {
  final Hire? hire;
  final String category;
  final String title;
  final bool receiptRequired;

  const ExpenseEntryScreen({
    super.key,
    this.hire,
    required this.category,
    required this.title,
    this.receiptRequired = true,
  });

  @override
  State<ExpenseEntryScreen> createState() => _ExpenseEntryScreenState();
}

class _ExpenseEntryScreenState extends State<ExpenseEntryScreen> {
  final _amountController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _photo;
  bool _saving = false;
  bool _loadingHistory = true;
  String? _error;

  List<HireExpense> _history = [];
  double _total = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final List<HireExpense> matching;
      final hire = widget.hire;
      if (hire != null) {
        final all = await ApiClient.instance.fetchExpenses(hire.id);
        matching = all.where((e) => e.category == widget.category).toList();
      } else {
        // No hire to scope to — show every entry in this category instead.
        matching = await ApiClient.instance.fetchDriverExpenses(category: widget.category);
      }
      if (!mounted) return;
      setState(() {
        _history = matching;
        _total = matching.fold(0, (sum, e) => sum + e.amount);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (photo == null) return;
      if (!mounted) return;
      setState(() => _photo = photo);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not open the camera: $e');
    }
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (widget.receiptRequired && _photo == null) {
      setState(() => _error = 'Take a photo of the receipt before saving.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final bytes = _photo != null ? await _photo!.readAsBytes() : null;
      final hire = widget.hire;
      if (hire != null) {
        await ApiClient.instance.addExpense(
          hire.id,
          category: widget.category,
          amount: amount,
          receiptBytes: bytes,
          receiptFilename: _photo?.name,
        );
      } else {
        await ApiClient.instance.addStandaloneExpense(
          category: widget.category,
          amount: amount,
          receiptBytes: bytes,
          receiptFilename: _photo?.name,
        );
      }
      if (!mounted) return;
      _amountController.clear();
      setState(() => _photo = null);
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${widget.title} added.')),
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
      appBar: AppBar(title: Text(widget.title)),
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
                Text(
                  'Add ${widget.title}',
                  style: const TextStyle(
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
                const SizedBox(height: 14),
                _PhotoPicker(
                  photo: _photo,
                  required: widget.receiptRequired,
                  onTap: _takePhoto,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.onNeon,
                            ),
                          )
                        : Text('Save ${widget.title}'),
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
          Row(
            children: [
              const Text(
                'History',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                'Total: \$${_total.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
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
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No ${widget.title.toLowerCase()} recorded yet.',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            )
          else
            ..._history.map((expense) => _HistoryTile(expense: expense)),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  final XFile? photo;
  final bool required;
  final VoidCallback onTap;

  const _PhotoPicker({required this.photo, required this.required, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        height: photo != null ? 160 : 96,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  kIsWeb
                      ? Image.network(photo!.path, fit: BoxFit.cover)
                      : Image.file(File(photo!.path), fit: BoxFit.cover),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.camera_alt, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text('Retake', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.camera_alt_outlined, color: AppColors.neon, size: 26),
                    const SizedBox(height: 6),
                    Text(
                      required ? 'Take Photo of Receipt' : 'Take Photo of Receipt (optional)',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HireExpense expense;

  const _HistoryTile({required this.expense});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y  h:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: expense.receiptUrl != null
                ? Image.network(
                    expense.receiptUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _receiptFallback(),
                  )
                : _receiptFallback(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '\$${expense.amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                if (expense.createdAt != null)
                  Text(
                    dateFormat.format(expense.createdAt!.toLocal()),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptFallback() {
    return Container(
      width: 48,
      height: 48,
      color: AppColors.surfaceElevated,
      alignment: Alignment.center,
      child: const Icon(Icons.receipt_long, color: AppColors.textMuted, size: 20),
    );
  }
}
