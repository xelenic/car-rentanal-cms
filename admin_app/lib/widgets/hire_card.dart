import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/hire.dart';
import '../theme/app_theme.dart';
import 'state_views.dart';

/// The colour a hire's status is shown in — one place, so the card and the
/// detail screen never disagree.
Color hireStatusColor(String status) => switch (status) {
      'completed' => AppColors.success,
      'started' => AppColors.info,
      'cancelled' => AppColors.danger,
      _ => AppColors.warning,
    };

/// One hire in a list: customer, status, where/when, driver and the money.
class HireCard extends StatelessWidget {
  const HireCard({super.key, required this.hire, required this.onTap});

  final Hire hire;
  final VoidCallback onTap;

  static final _currency = NumberFormat.currency(locale: 'en_LK', symbol: 'Rs. ', decimalDigits: 0);
  static final _dateFormat = DateFormat('MMM d, y · h:mm a');

  @override
  Widget build(BuildContext context) {
    final route = _routeSummary();

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      hire.customer?.name ?? 'Hire #${hire.id}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pill(label: hire.statusLabel, color: hireStatusColor(hire.status)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.local_offer_outlined, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(hire.tourTypeLabel, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  if (hire.isUpcoming) ...[
                    const SizedBox(width: 8),
                    const Pill(label: 'Upcoming', color: AppColors.info),
                  ],
                ],
              ),
              if (route != null) ...[
                const SizedBox(height: 4),
                _line(Icons.place_outlined, route),
              ],
              if (hire.startTime != null) ...[
                const SizedBox(height: 4),
                _line(Icons.schedule_rounded, _dateFormat.format(hire.startTime!)),
              ],
              if (hire.driver != null) ...[
                const SizedBox(height: 4),
                _line(Icons.person_outline_rounded, hire.driver!.name),
              ],
              if (hire.isCancelled && (hire.cancelReason ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                _line(Icons.block_rounded, hire.cancelReason!.trim(), color: AppColors.danger, maxLines: 2),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _currency.format(hire.hireFullValue),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  if (hire.isCredit) _PaymentBadge(hire: hire),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(IconData icon, String text, {Color color = AppColors.textSecondary, int maxLines = 1}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 14, color: color == AppColors.textSecondary ? AppColors.textMuted : color),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12.5, color: color),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String? _routeSummary() {
    if (hire.fromLocation != null && hire.toLocation != null) {
      return '${hire.fromLocation} → ${hire.toLocation}';
    }
    if (hire.stayLocations.isNotEmpty) {
      return hire.stayLocations.join(', ');
    }
    if (hire.dayLocations.isNotEmpty) {
      return hire.dayLocations.expand((day) => day).join(', ');
    }
    if (hire.package != null) {
      return hire.package;
    }
    return null;
  }
}

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.hire});

  final Hire hire;

  @override
  Widget build(BuildContext context) {
    if (hire.isFullyPaid) {
      return const Pill(label: 'Fully Paid', color: AppColors.success, icon: Icons.check_circle_rounded);
    }
    if (hire.paymentStatus == 'partial') {
      return const Pill(label: 'Partially Paid', color: AppColors.warning, icon: Icons.pie_chart_rounded);
    }
    return const Pill(label: 'Unpaid', color: AppColors.danger, icon: Icons.error_outline_rounded);
  }
}
