import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A compact dropdown for picking a year or a month from a fixed list of
/// options (typically only the periods that actually have data). Passing
/// `null` for [onChanged] renders it disabled.
class PeriodDropdown extends StatelessWidget {
  final String hint;
  final int? value;
  final List<int> items;
  final String Function(int) labelBuilder;
  final void Function(int?)? onChanged;

  const PeriodDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onChanged == null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: disabled ? AppColors.surface : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int?>(
          value: value,
          hint: Text(
            hint,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
          isExpanded: true,
          isDense: true,
          dropdownColor: AppColors.surfaceElevated,
          icon: Icon(Icons.keyboard_arrow_down, color: disabled ? AppColors.textMuted : AppColors.textSecondary, size: 18),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          items: [
            DropdownMenuItem<int?>(
              value: null,
              child: Text(hint, style: const TextStyle(color: AppColors.textSecondary)),
            ),
            ...items.map(
              (item) => DropdownMenuItem<int?>(
                value: item,
                child: Text(labelBuilder(item)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
