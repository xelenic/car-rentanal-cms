import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hire.dart';
import '../screens/hire_detail_screen.dart';
import '../theme/app_theme.dart';

/// Compact card summarizing a hire's route and status, used anywhere a
/// list of hires is shown (Notifications tab, Home screen sections).
/// Tapping it opens the full hire detail screen.
class HireRouteCard extends StatelessWidget {
  final Hire hire;

  /// Called when the driver comes back from the hire's screen — a list uses it
  /// to reload, since the hire may have been started, completed or cancelled.
  final VoidCallback? onReturn;

  const HireRouteCard({super.key, required this.hire, this.onReturn});

  /// When it is scheduled for, or — for a cancelled hire — when it was
  /// cancelled: what a driver scanning a tab wants to see at a glance.
  String? get _when {
    final format = DateFormat('MMM d, h:mm a');

    if (hire.isCancelled) {
      return hire.cancelledAt != null ? 'Cancelled ${format.format(hire.cancelledAt!.toLocal())}' : 'Cancelled';
    }
    if (hire.isCompleted || hire.startTime == null) return null;

    return 'Scheduled ${format.format(hire.startTime!.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => HireDetailScreen(hire: hire)))
              .then((_) => onReturn?.call());
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.neon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.alt_route, color: AppColors.neon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            hire.tourTypeLabel,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        HireStatusPill(hire: hire),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hire.routeSummary,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_when != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _when!,
                        style: TextStyle(
                          color: hire.isCancelled ? AppColors.danger : AppColors.textMuted,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

class HireStatusPill extends StatelessWidget {
  final Hire hire;

  const HireStatusPill({super.key, required this.hire});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (hire.status) {
      case 'started':
        color = AppColors.neon;
        break;
      case 'completed':
        color = AppColors.info;
        break;
      case 'cancelled':
        color = AppColors.danger;
        break;
      default:
        color = AppColors.textMuted;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        hire.statusLabel,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700),
      ),
    );
  }
}
