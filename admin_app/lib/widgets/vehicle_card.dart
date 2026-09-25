import 'package:flutter/material.dart';

import '../models/hire_tab.dart';
import '../models/vehicle.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'state_views.dart';

Color conditionColor(String condition) => switch (condition) {
      'New' || 'Excellent' => AppColors.success,
      'Good' => AppColors.info,
      'Fair' => AppColors.warning,
      'Poor' => AppColors.danger,
      _ => AppColors.textSecondary,
    };

/// The colour each hire tab is shown in, on the vehicle cards and its tab bar.
Color hireTabColor(HireTab tab) => switch (tab) {
      HireTab.all => AppColors.textSecondary,
      HireTab.today => AppColors.primary,
      HireTab.scheduled => AppColors.info,
      HireTab.completed => AppColors.success,
      HireTab.cancelled => AppColors.danger,
    };

/// A vehicle on the dashboard: what it is, what it has earned, and how many
/// hires it has in each tab. Tapping opens the vehicle's own page.
class VehicleCard extends StatelessWidget {
  const VehicleCard({super.key, required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  static const _chipTabs = [HireTab.today, HireTab.scheduled, HireTab.completed, HireTab.cancelled];

  @override
  Widget build(BuildContext context) {
    final stats = vehicle.stats;

    return Card(
      child: InkWell(
        key: Key('vehicle-card-${vehicle.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.directions_car_filled_rounded, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.model,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${countOf(vehicle.seats, 'seat')} · ${countOf(vehicle.pax, 'passenger')}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pill(label: vehicle.condition, color: conditionColor(vehicle.condition)),
                ],
              ),
              if (stats.counts.running > 0) ...[
                const SizedBox(height: 10),
                Pill(
                  label: '${stats.counts.running} running now',
                  color: AppColors.info,
                  icon: Icons.play_circle_fill_rounded,
                ),
              ],
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Metric(label: 'Hires', value: '${stats.hireCount}'),
                  _Metric(label: 'Hire value', value: formatRs(stats.hireFullValueTotal)),
                  _Metric(label: 'Commission', value: formatRs(stats.commissionTotal)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'This month · ${countOf(stats.monthHireCount, 'hire')} · ${formatRs(stats.monthHireFullValueTotal)}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final tab in _chipTabs) _TabChip(tab: tab, count: stats.counts.of(tab)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}

/// "Today 2" — coloured when there is something in the tab, grey when not.
class _TabChip extends StatelessWidget {
  const _TabChip({required this.tab, required this.count});

  final HireTab tab;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = count > 0 ? hireTabColor(tab) : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: count > 0 ? 0.1 : 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text.rich(
        TextSpan(
          text: '${tab.label} ',
          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
          children: [
            TextSpan(text: '$count', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
