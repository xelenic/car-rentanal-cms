import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/driver_expense.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

/// The icon an expense's category is shown with — mirrors the driver app's
/// own category set (HireExpense::CATEGORIES on the backend).
IconData driverExpenseCategoryIcon(String category) => switch (category) {
      'fuel' => Icons.local_gas_station_outlined,
      'repair' => Icons.build_outlined,
      'emergency' => Icons.warning_amber_rounded,
      'highway' => Icons.toll_outlined,
      'food' => Icons.restaurant_outlined,
      'room' => Icons.hotel_outlined,
      'parking' => Icons.local_parking_outlined,
      _ => Icons.receipt_long_outlined,
    };

/// One expense a driver logged: category, amount, when, which hire (if any)
/// and a receipt thumbnail (if one was attached).
class DriverExpenseCard extends StatelessWidget {
  const DriverExpenseCard({super.key, required this.expense, this.onTap, this.onEdit, this.onDelete});

  final DriverExpense expense;
  final VoidCallback? onTap;

  /// Shown only when non-null — gated by the signed-in user's own
  /// hires.update/hires.delete permissions (same as the web admin panel).
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static final _dateFormat = DateFormat('MMM d, y · h:mm a');

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Icon(driverExpenseCategoryIcon(expense.category), size: 19, color: AppColors.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            expense.categoryLabel,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatRsExact(expense.amount),
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: AppColors.danger),
                        ),
                      ],
                    ),
                    if (expense.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _dateFormat.format(expense.createdAt!),
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                    if (expense.hireTourTypeLabel != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.local_offer_outlined, size: 13, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              expense.hireTourTypeLabel!,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (expense.receiptUrl != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          expense.receiptUrl!,
                          height: 72,
                          width: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                    if (onEdit != null || onDelete != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (onEdit != null)
                            IconButton(
                              key: Key('edit-expense-${expense.id}'),
                              visualDensity: VisualDensity.compact,
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Edit',
                              onPressed: onEdit,
                            ),
                          if (onDelete != null)
                            IconButton(
                              key: Key('delete-expense-${expense.id}'),
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                              tooltip: 'Delete',
                              onPressed: onDelete,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
