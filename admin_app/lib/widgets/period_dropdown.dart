import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A compact dropdown for picking a year or a month from a fixed list of
/// options. Used by the Overview screen's year/month filter.
class PeriodDropdown extends StatelessWidget {
  final String hint;
  final int value;
  final List<int> items;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onChanged;

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          isDense: true,
          dropdownColor: AppColors.surfaceElevated,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 18),
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
          items: [
            for (final item in items) DropdownMenuItem<int>(value: item, child: Text(labelBuilder(item))),
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
