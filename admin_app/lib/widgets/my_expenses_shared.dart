import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import '../util/format.dart';
import 'state_views.dart';

/// ‹ September 2026 › — steps a month at a time; tapping the name picks any
/// month. A trailing Categories icon shows when the caller passes one (only
/// the Expenses section has categories to manage).
class MonthBar extends StatelessWidget {
  const MonthBar({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.onPick,
    this.onManageCategories,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPick;
  final VoidCallback? onManageCategories;

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
          if (onManageCategories != null)
            IconButton(
              key: const Key('manage-categories'),
              tooltip: 'Categories',
              icon: const Icon(Icons.sell_outlined),
              onPressed: onManageCategories,
            ),
        ],
      ),
    );
  }
}

/// One expense or one piece of other income: title, an optional category
/// pill, the date, notes and the amount — with an Edit / Delete menu when the
/// user may do either. [keyPrefix] ('expense' / 'income') names its keys.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.keyPrefix,
    required this.id,
    required this.title,
    required this.dateLabel,
    required this.amount,
    required this.showMenu,
    this.pillLabel,
    this.notes,
    this.amountColor,
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
  final Color? amountColor;
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
                        Text(dateLabel, style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      ],
                    ),
                    if (notes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
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
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: amountColor ?? AppColors.textPrimary),
                ),
              ),
              if (showMenu)
                PopupMenuButton<String>(
                  key: Key('$keyPrefix-menu-$id'),
                  tooltip: 'More',
                  icon: Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textMuted),
                  onSelected: (value) => value == 'edit' ? onEdit?.call() : onDelete?.call(),
                  itemBuilder: (_) => [
                    if (onEdit != null) const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    if (onDelete != null)
                      PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppColors.danger))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [MonthPickerSheet] and returns the (year, month) picked, or null if
/// dismissed — the one month-picker flow every section (and the landing
/// page) shares.
Future<(int, int)?> pickMonth(BuildContext context, {required List<int> years, required int year, required int month}) {
  final offered = ({...years, year}.toList())..sort((a, b) => b.compareTo(a));
  return showModalBottomSheet<(int, int)>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => MonthPickerSheet(years: offered, year: year, month: month),
  );
}

/// Year and month, in one sheet: pick a year, tap a month.
class MonthPickerSheet extends StatefulWidget {
  const MonthPickerSheet({super.key, required this.years, required this.year, required this.month});

  final List<int> years;
  final int year;
  final int month;

  @override
  State<MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<MonthPickerSheet> {
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
