import 'package:flutter/material.dart';

import '../models/vehicle.dart';
import '../theme/app_theme.dart';

/// A vehicle on the home screen: just its icon and name. Tapping opens the
/// vehicle's page with everything else.
class VehicleTile extends StatelessWidget {
  const VehicleTile({super.key, required this.vehicle, required this.onTap});

  final Vehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        key: Key('vehicle-card-${vehicle.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.directions_car_filled_rounded, size: 32, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                vehicle.model,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
