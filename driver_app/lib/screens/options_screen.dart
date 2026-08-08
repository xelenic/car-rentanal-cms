import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'arrears_loan_screen.dart';
import 'expense_entry_screen.dart';
import 'placeholder_screen.dart';
import 'salary_advance_screen.dart';
import 'salary_screen.dart';
import 'vehicle_repair_screen.dart';

class _OptionItem {
  final String label;
  final IconData icon;
  final Color color;
  final String? category;
  final bool receiptRequired;

  const _OptionItem(this.label, this.icon, this.color, [this.category, this.receiptRequired = true]);
}

// Each tile gets its own accent color so the grid reads as distinct
// destinations at a glance, rather than eleven identical neon chips.
// receiptRequired mirrors the hire detail quick actions' semantics: only
// Fuel requires a photo, the rest are optional.
const _options = <_OptionItem>[
  _OptionItem('Fuel Expenses', Icons.local_gas_station_outlined, Color(0xFFFFA726), 'fuel', true),
  _OptionItem('Driver Foods', Icons.restaurant_outlined, Color(0xFFFF7043), 'food', false),
  _OptionItem('Room Charges', Icons.hotel_outlined, Color(0xFF42A5F5), 'room', false),
  _OptionItem('Parking Tickets', Icons.local_parking_outlined, Color(0xFFEC407A), 'parking', false),
  _OptionItem('Highway Charges', Icons.toll_outlined, Color(0xFF26C6DA), 'highway', false),
  _OptionItem('Others', Icons.more_horiz_outlined, Color(0xFF9AA1AC)),
  _OptionItem('My Salary', Icons.payments_outlined, AppColors.neon),
  _OptionItem('Salary Advance', Icons.request_quote_outlined, Color(0xFF5C6BC0)),
  _OptionItem('Loan Arrears', Icons.account_balance_outlined, Color(0xFF7E57C2)),
  _OptionItem('Payslips & Current Collection', Icons.receipt_long_outlined, Color(0xFF26A69A)),
  _OptionItem('Vehicle Repair', Icons.car_repair_outlined, Color(0xFFEF5350)),
];

class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Options')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _options.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 0.92,
        ),
        itemBuilder: (context, index) {
          final option = _options[index];
          return _OptionTile(
            label: option.label,
            icon: option.icon,
            color: option.color,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) {
                    if (option.label == 'My Salary') {
                      return const SalaryScreen();
                    }
                    if (option.label == 'Salary Advance') {
                      return const SalaryAdvanceScreen();
                    }
                    if (option.label == 'Loan Arrears') {
                      return const ArrearsLoanScreen();
                    }
                    if (option.label == 'Vehicle Repair') {
                      return const VehicleRepairScreen();
                    }
                    if (option.category != null) {
                      return ExpenseEntryScreen(
                        category: option.category!,
                        title: option.label,
                        receiptRequired: option.receiptRequired,
                      );
                    }
                    return PlaceholderScreen(title: option.label, icon: option.icon);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.14),
                  border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.22),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
