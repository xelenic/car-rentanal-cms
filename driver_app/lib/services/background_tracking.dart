import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/tracking_status.dart';
import 'api_client.dart';

/// How often a tracked hire's position is recorded — shared by the Android
/// background service and the in-app timer fallback (web/other platforms) so
/// the two can never drift apart.
const Duration kTrackingPingInterval = Duration(seconds: 15);

/// The OS-level background service only exists on Android. Everywhere else
/// (the web preview, desktop) tracking keeps using the in-app timer, which
/// only runs while the hire screen is open.
bool get backgroundTrackingSupported =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

const _hireIdsKey = 'tracking_hire_ids';
const _serviceId = 4101;
const _notificationIconMetaData = 'com.carrentalcms.driver_app.TRACKING_NOTIFICATION_ICON';

/// Keeps recording a hire's position after the app is minimized or the
/// screen locks, ride-hailing style: an Android foreground service (type
/// "location") shows a pinned notification for as long as any hire is being
/// tracked, and ends the moment the last one is stopped or completed.
///
/// The service runs its own isolate ([_TrackingTaskHandler]) — it reads the
/// GPS position and posts it to the API itself, and hands each result back to
/// the hire screen (when it's open) as a plain map, see [addListener].
class BackgroundTracking {
  BackgroundTracking._();

  /// Call once from main(), before runApp.
  static void initialize() {
    if (!backgroundTrackingSupported) return;

    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'hire_tracking',
        channelName: 'Hire tracking',
        channelDescription: 'Shown while your location is being recorded for an active hire.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(kTrackingPingInterval.inMilliseconds),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        // Keep the CPU/Wi-Fi awake so pings keep flowing with the screen
        // off instead of being deferred by Doze.
        allowWakeLock: true,
        allowWifiLock: true,
        // Restart if the OS kills the app process, and keep going if the
        // driver swipes the app away — only stopping the hire ends tracking.
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  /// Android 13+ only shows the pinned notification once the user allows
  /// notifications. Tracking works either way (the service still runs, it's
  /// just less visible), so a "no" never blocks starting a hire.
  static Future<void> requestNotificationPermission() async {
    if (!backgroundTrackingSupported) return;

    try {
      final permission = await FlutterForegroundTask.checkNotificationPermission();
      if (permission != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {
      // Not being able to ask isn't a reason to stop tracking.
    }
  }

  /// Starts (or keeps) the service for [hireId]. Safe to call again for a
  /// hire that's already tracked, and for a second hire while one is already
  /// running — the service records every hire in the set on each tick.
  /// Returns false if the service couldn't be started.
  static Future<bool> start(int hireId) async {
    if (!backgroundTrackingSupported) return false;

    final ids = (await _savedHireIds())..add(hireId);
    await _saveHireIds(ids);

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: _title,
        notificationText: _startText(ids),
      );
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.location],
      notificationTitle: _title,
      notificationText: _startText(ids),
      notificationIcon: const NotificationIcon(
        metaDataName: _notificationIconMetaData,
        backgroundColor: Color(0xFF0EA5E9),
      ),
      callback: trackingServiceEntryPoint,
    );

    if (result is ServiceRequestFailure) {
      debugPrint('Could not start the tracking service: ${result.error}');
      return false;
    }
    return true;
  }

  /// Stops tracking [hireId] and shuts the service (and its pinned
  /// notification) down once no hire is left.
  static Future<void> stop(int hireId) async {
    if (!backgroundTrackingSupported) return;

    await _removeHires({hireId});
  }

  /// Ends all tracking — used when the driver signs out.
  static Future<void> stopAll() async {
    if (!backgroundTrackingSupported) return;

    await _saveHireIds({});
    await _stopServiceIfRunning();
  }

  /// Receives everything the service reports while the app is open — see
  /// [_TrackingTaskHandler] for the message shapes.
  static void addListener(void Function(Object data) listener) {
    if (!backgroundTrackingSupported) return;
    FlutterForegroundTask.addTaskDataCallback(listener);
  }

  static void removeListener(void Function(Object data) listener) {
    if (!backgroundTrackingSupported) return;
    FlutterForegroundTask.removeTaskDataCallback(listener);
  }

  static const _title = 'Hire tracking is on';

  static String _startText(Set<int> ids) => ids.length == 1
      ? 'Hire #${ids.first} · sharing your location'
      : '${_hireLabel(ids)} · sharing your location';

  static String _hireLabel(Set<int> ids) {
    final sorted = ids.toList()..sort();
    return sorted.length == 1 ? 'Hire #${sorted.first}' : 'Hires ${sorted.map((id) => '#$id').join(', ')}';
  }

  static Future<Set<int>> _savedHireIds() async {
    final raw = await FlutterForegroundTask.getData<String>(key: _hireIdsKey) ?? '';
    return raw.split(',').map(int.tryParse).whereType<int>().toSet();
  }

  static Future<void> _saveHireIds(Set<int> ids) async {
    final sorted = ids.toList()..sort();
    await FlutterForegroundTask.saveData(key: _hireIdsKey, value: sorted.join(','));
  }

  /// Re-reads the saved set before writing so a slow tick in the service
  /// can't resurrect a hire the driver just stopped (removals only ever
  /// subtract from the current value).
  static Future<Set<int>> _removeHires(Set<int> hireIds) async {
    final remaining = (await _savedHireIds())..removeAll(hireIds);
    await _saveHireIds(remaining);
    if (remaining.isEmpty) {
      await _stopServiceIfRunning();
    }
    return remaining;
  }

  static Future<void> _stopServiceIfRunning() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

/// Entry point of the service's isolate — must stay a top-level function.
@pragma('vm:entry-point')
void trackingServiceEntryPoint() {
  FlutterForegroundTask.setTaskHandler(_TrackingTaskHandler());
}

/// Runs inside the foreground service. Every [kTrackingPingInterval] it reads
/// one GPS fix and posts it for each hire being tracked, then updates the
/// pinned notification and reports back to the UI with plain maps:
///
///   {'type': 'status', 'hire_id': 33, ...TrackingStatus.toJson()}
///   {'type': 'error', 'message': '...'}
class _TrackingTaskHandler extends TaskHandler {
  bool _recording = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_record());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _record() async {
    // A slow GPS fix or request must not stack ticks on top of each other.
    if (_recording) return;
    _recording = true;

    try {
      final hireIds = await BackgroundTracking._savedHireIds();
      if (hireIds.isEmpty) {
        await FlutterForegroundTask.stopService();
        return;
      }

      final Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
      } on LocationServiceDisabledException {
        _report(hireIds, 'Location is turned off', 'Turn on GPS so this hire can keep being tracked.');
        return;
      } on PermissionDeniedException {
        _report(hireIds, 'Location permission needed', 'Allow location for the app in Settings to keep tracking.');
        return;
      } on TimeoutException {
        _report(hireIds, 'Waiting for GPS', 'No location fix yet — still trying.');
        return;
      }

      final ended = <int>{};
      var signedOut = false;
      var unreachable = false;
      TrackingStatus? latest;

      for (final hireId in hireIds) {
        try {
          final status = await ApiClient.instance.sendTrackingPoint(
            hireId,
            latitude: position.latitude,
            longitude: position.longitude,
          );
          latest = status;
          FlutterForegroundTask.sendDataToMain({
            'type': 'status',
            'hire_id': hireId,
            ...status.toJson(),
          });

          // Stopped or completed from somewhere else (another device, the
          // admin panel) — nothing left to track for it.
          if (!status.isTracking) ended.add(hireId);
        } on ApiException catch (e) {
          final code = e.statusCode;
          if (code == 401) {
            signedOut = true;
          } else if (code == 403 || code == 404 || code == 422) {
            // No longer this driver's active hire — retrying can't help.
            ended.add(hireId);
          } else {
            unreachable = true;
          }
        } catch (_) {
          unreachable = true;
        }
      }

      if (signedOut) {
        await BackgroundTracking.stopAll();
        return;
      }

      final remaining = ended.isEmpty
          ? hireIds
          : await BackgroundTracking._removeHires(ended);
      if (remaining.isEmpty) return; // the service was shut down with the last hire

      if (unreachable) {
        _report(remaining, 'Hire tracking is on', "Can't reach the server — will retry.");
        return;
      }

      final updated = DateFormat('h:mm:ss a').format(DateTime.now());
      final label = BackgroundTracking._hireLabel(remaining);
      final km = remaining.length == 1 ? latest?.totalDistanceKm : null;
      await FlutterForegroundTask.updateService(
        notificationTitle: BackgroundTracking._title,
        notificationText: km == null
            ? '$label · updated $updated'
            : '$label · ${km.toStringAsFixed(1)} km · updated $updated',
      );
    } finally {
      _recording = false;
    }
  }

  void _report(Set<int> hireIds, String title, String text) {
    unawaited(FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: '${BackgroundTracking._hireLabel(hireIds)} · $text',
    ));
    FlutterForegroundTask.sendDataToMain({'type': 'error', 'message': text});
  }
}
