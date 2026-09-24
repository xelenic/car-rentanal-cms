import 'package:flutter/material.dart';

import '../services/background_tracking.dart';
import '../theme/app_theme.dart';

/// Walks the driver through the two phone settings that decide whether
/// tracking survives another app being opened (see [BackgroundAccess]):
///
///  1. Android's one-tap "always allow running in the background" dialog.
///  2. Location → "Allow all the time", which Android 11+ only lets the driver
///     pick in Settings, so an explanation and a shortcut are shown first.
///
/// Meant to be called *after* the tracking service is already running — the
/// steps leave the app (system dialogs / Settings), and Android 12+ refuses
/// to start a location service from the background.
///
/// What the driver picks in Settings is only known once they come back, so
/// callers re-check on resume (see [BackgroundTracking.checkAccess]).
Future<void> offerBackgroundAccess(BuildContext context) async {
  var access = await BackgroundTracking.checkAccess();
  if (access.isComplete) return;

  if (!access.batteryUnrestricted) {
    await BackgroundTracking.requestBatteryExemption();
    access = await BackgroundTracking.checkAccess();
  }

  if (access.locationAlways || !context.mounted) return;

  final openSettings = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text(
        'Keep tracking when you switch apps',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 17),
      ),
      content: const Text(
        'So this hire keeps being recorded while you use Maps or other apps, '
        'or when the screen is off:\n\n'
        '1. Tap "Open Settings"\n'
        '2. Open Permissions → Location\n'
        '3. Choose "Allow all the time"\n\n'
        'On Xiaomi, Oppo, Vivo, Huawei and Samsung phones, also switch on '
        '"Autostart" / "Allow background activity" for this app and set its '
        'battery to "Unrestricted".',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now', style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );

  if (openSettings == true) {
    await BackgroundTracking.openLocationSettings();
  }
}

/// Copy for the reminder shown on an active hire while [access] is still
/// incomplete, or null when there is nothing to fix.
String? backgroundAccessNotice(BackgroundAccess? access) {
  if (access == null || access.isComplete) return null;

  if (!access.locationAlways && !access.batteryUnrestricted) {
    return 'Tracking may pause when you switch to other apps. Set Location to "Allow all the time" and turn off battery restrictions for this app.';
  }
  if (!access.locationAlways) {
    return 'Tracking may pause when you switch to other apps. Set Location to "Allow all the time" for this app.';
  }
  return 'Tracking may pause when you switch to other apps. Turn off battery restrictions for this app.';
}
