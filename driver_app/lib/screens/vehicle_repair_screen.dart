import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'vehicle_maintenance_entry_screen.dart';

class _VehicleMaintenanceType {
  final String type;
  final String title;
  final String subtitle;
  final IconData icon;

  const _VehicleMaintenanceType(this.type, this.title, this.subtitle, this.icon);
}

const _types = <_VehicleMaintenanceType>[
  _VehicleMaintenanceType(
    'service',
    'Vehicle Service',
    'Mileage, cost and bill for a routine service',
    Icons.build_circle_outlined,
  ),
  _VehicleMaintenanceType(
    'repair',
    'Vehicle Repair',
    'Cost and bill for a repair',
    Icons.car_repair_outlined,
  ),
  _VehicleMaintenanceType(
    'parts',
    'Vehicle Parts',
    'Cost and bill for replaced parts',
    Icons.settings_outlined,
  ),
];

/// Hub for the three Vehicle Repair sub-types. None of these are counted as
/// a deductible expense or affect the driver's salary — they're purely a
/// vehicle maintenance log.
class VehicleRepairScreen extends StatelessWidget {
  const VehicleRepairScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vehicle Repair')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: _types
            .map(
              (item) => _TypeCard(
                title: item.title,
                subtitle: item.subtitle,
                icon: item.icon,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => VehicleMaintenanceEntryScreen(
                      type: item.type,
                      title: item.title,
                      icon: item.icon,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.neon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.neon, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
