import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../models/tracking_status.dart';
import 'api_client.dart';
import 'pending_track_points.dart';

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
const _pendingPointsKey = 'tracking_pending_points';
const _serviceId = 4101;
const _notificationIconMetaData = 'com.carrentalcms.driver_app.TRACKING_NOTIFICATION_ICON';

/// What the driver has allowed on the phone for tracking to survive the app
/// being minimized. The foreground service itself always runs; these two are
/// what stop phones from killing or starving it once another app is opened.
class BackgroundAccess {
  /// Location permission is "Allow all the time" (not just "While using the
  /// app") — lets the service keep reading the GPS even if the OS had to
  /// restart it while the app was closed.
  final bool locationAlways;

  /// The app is exempt from battery optimisation (Doze / app standby).
  final bool batteryUnrestricted;

  const BackgroundAccess({required this.locationAlways, required this.batteryUnrestricted});

  static const complete = BackgroundAccess(locationAlways: true, batteryUnrestricted: true);

  bool get isComplete => locationAlways && batteryUnrestricted;
}

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
    return _launch(ids);
  }

  /// Brings the service back after the phone killed it (aggressive battery
  /// savers, a reboot, "clear all" in recents) while a hire was still being
  /// tracked. The saved hire list survives that, so this only needs to look
  /// at it — call it whenever the app opens or comes back to the foreground.
  /// A service that is already running is left alone.
  static Future<bool> ensureRunning() async {
    if (!backgroundTrackingSupported) return false;

    final ids = await _savedHireIds();
    if (ids.isEmpty) return false;
    if (await FlutterForegroundTask.isRunningService) return true;

    return _launch(ids);
  }

  /// Re-attaches the service to the hires the server says are being tracked
  /// (from the hire list) — covers the saved list being lost, e.g. after the
  /// app's data was cleared, on top of what [ensureRunning] handles.
  static Future<void> resume(Iterable<int> trackedHireIds) async {
    if (!backgroundTrackingSupported) return;

    final ids = trackedHireIds.toSet();
    if (ids.isEmpty) {
      await ensureRunning();
      return;
    }

    final saved = await _savedHireIds();
    final merged = {...saved, ...ids};
    await _saveHireIds(merged);
    await _launch(merged);
  }

  static Future<bool> _launch(Set<int> ids) async {
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

  /// Whether the phone's settings currently let tracking survive being
  /// minimized — see [BackgroundAccess]. Anything that can't be read counts
  /// as fine, so a plugin hiccup never nags the driver.
  static Future<BackgroundAccess> checkAccess() async {
    if (!backgroundTrackingSupported) return BackgroundAccess.complete;

    var locationAlways = true;
    var batteryUnrestricted = true;

    try {
      locationAlways = await Geolocator.checkPermission() == LocationPermission.always;
    } catch (_) {}
    try {
      batteryUnrestricted = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {}

    return BackgroundAccess(locationAlways: locationAlways, batteryUnrestricted: batteryUnrestricted);
  }

  /// Shows Android's one-tap "let this app always run in the background?"
  /// dialog. Does nothing if the app is already exempt.
  static Future<void> requestBatteryExemption() async {
    if (!backgroundTrackingSupported) return;

    try {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (_) {
      // The dialog is a courtesy — tracking still works without the exemption.
    }
  }

  /// Opens this app's page in system Settings, where Location → "Allow all
  /// the time" can be chosen (Android 11+ only allows that choice there).
  static Future<void> openLocationSettings() async {
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
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
    await FlutterForegroundTask.saveData(key: _pendingPointsKey, value: '');
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
    await _discardPendingPoints(hireIds);
    if (remaining.isEmpty) {
      await _stopServiceIfRunning();
    }
    return remaining;
  }

  /// Positions still waiting to be sent for a hire that just ended can never
  /// be accepted (the server refuses points for a stopped hire), and would be
  /// wrongly replayed if the same hire is started again later.
  static Future<void> _discardPendingPoints(Set<int> hireIds) async {
    final pending = PendingTrackPoints.decode(await FlutterForegroundTask.getData<String>(key: _pendingPointsKey));
    if (pending.isEmpty) return;

    for (final id in hireIds) {
      pending.removeHire(id);
    }
    await FlutterForegroundTask.saveData(key: _pendingPointsKey, value: pending.encode());
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
/// one GPS fix, queues it for each hire being tracked and sends everything
/// queued, then updates the pinned notification and reports back to the UI
/// with plain maps:
///
///   {'type': 'status', 'hire_id': 33, ...TrackingStatus.toJson()}
///   {'type': 'error', 'message': '...'}
///
/// Nothing in a tick may wait forever — the GPS reads and the uploads all
/// have time limits — because a tick that never finishes would silently stop
/// every later one.
class _TrackingTaskHandler extends TaskHandler {
  /// Queued points sent per hire per tick: enough to drain a backlog quickly
  /// after signal returns without one tick turning into minutes of uploads.
  static const _pointsPerTick = 10;

  /// A saved fix this old is still better than no point at all when the GPS
  /// can't produce a fresh one (tunnel, parking garage, phone in a bag).
  static const _maxLastKnownAge = Duration(minutes: 2);

  /// A tick still "running" after this long is presumed stuck and no longer
  /// blocks the next one.
  static const _stuckAfter = Duration(minutes: 3);

  PendingTrackPoints _pending = PendingTrackPoints();
  bool _recording = false;
  DateTime _recordingSince = DateTime.now();
  int _run = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Points queued before the service was killed and restarted.
    _pending = PendingTrackPoints.decode(await FlutterForegroundTask.getData<String>(key: _pendingPointsKey));
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_record());
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _record() async {
    // A slow tick must not stack more ticks on top of it — unless it has been
    // stuck for so long that waiting any further would just lose points.
    if (_recording && DateTime.now().difference(_recordingSince) < _stuckAfter) return;

    final run = ++_run;
    _recording = true;
    _recordingSince = DateTime.now();

    try {
      await _recordOnce();
    } catch (e) {
      debugPrint('Tracking tick failed: $e');
    } finally {
      if (run == _run) _recording = false;
    }
  }

  Future<void> _recordOnce() async {
    final hireIds = await BackgroundTracking._savedHireIds();
    if (hireIds.isEmpty) {
      _pending = PendingTrackPoints();
      await _savePending();
      await FlutterForegroundTask.stopService();
      return;
    }

    _pending.retainHires(hireIds);

    final fix = await _readFix(hireIds);
    if (fix != null) {
      final capturedAt = _fixTime(fix);
      for (final hireId in hireIds) {
        _pending.add(PendingTrackPoint(
          hireId: hireId,
          latitude: fix.latitude,
          longitude: fix.longitude,
          capturedAt: capturedAt,
        ));
      }
    }

    // No GPS fix and nothing waiting from earlier — _readFix has already told
    // the driver why.
    if (_pending.isEmpty) return;

    // Saved before any network call so a fix survives the service being
    // killed mid-upload.
    await _savePending();

    final ended = <int>{};
    var signedOut = false;
    var unreachable = false;
    TrackingStatus? latest;

    for (final hireId in hireIds) {
      if (_pending.countForHire(hireId) == 0) continue;

      try {
        final status = await _pending.flushHire(
          hireId,
          (point) => ApiClient.instance.sendTrackingPoint(
            hireId,
            latitude: point.latitude,
            longitude: point.longitude,
            recordedAt: point.recordedAtFor(DateTime.now().toUtc()),
          ),
          limit: _pointsPerTick,
        );
        if (status == null) continue;

        latest = status;
        FlutterForegroundTask.sendDataToMain({
          'type': 'status',
          'hire_id': hireId,
          ...status.toJson(),
        });

        // Stopped or completed from somewhere else (another device, the
        // admin panel) — nothing left to track for it.
        if (!status.isTracking) {
          ended.add(hireId);
          _pending.removeHire(hireId);
        }
      } on ApiException catch (e) {
        final code = e.statusCode;
        if (code == 401) {
          signedOut = true;
        } else if (code == 403 || code == 404 || code == 422) {
          // No longer this driver's active hire — retrying can't help.
          ended.add(hireId);
          _pending.removeHire(hireId);
        } else {
          unreachable = true;
        }
      } catch (_) {
        // Offline, timed out, DNS failure… the unsent points stay queued.
        unreachable = true;
      }
    }

    if (signedOut) {
      await BackgroundTracking.stopAll();
      return;
    }

    await _savePending();

    final remaining = ended.isEmpty
        ? hireIds
        : await BackgroundTracking._removeHires(ended);
    if (remaining.isEmpty) return; // the service was shut down with the last hire

    if (unreachable) {
      final waiting = _pending.length;
      _report(
        remaining,
        'Hire tracking is on',
        waiting > 0
            ? "Offline — $waiting point${waiting == 1 ? '' : 's'} saved, will send when the connection is back."
            : "Can't reach the server — will retry.",
      );
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
  }

  /// One position for this tick, trying progressively easier options so a bad
  /// GPS moment costs at most a slightly rougher point instead of a missing
  /// one: a high-accuracy fix, then a network-quality fix, then the phone's
  /// last known position if it's recent. Returns null (after telling the
  /// driver why) if none of them works.
  Future<Position?> _readFix(Set<int> hireIds) async {
    try {
      return await _currentPosition(LocationAccuracy.high, const Duration(seconds: 12));
    } on TimeoutException {
      // fall through to the easier options below
    } on LocationServiceDisabledException {
      _report(hireIds, 'Location is turned off', 'Turn on GPS so this hire can keep being tracked.');
      return null;
    } on PermissionDeniedException {
      _report(hireIds, 'Location permission needed', 'Allow location for the app in Settings to keep tracking.');
      return null;
    } catch (_) {
      // unknown failure — the fallbacks may still work
    }

    try {
      return await _currentPosition(LocationAccuracy.medium, const Duration(seconds: 6));
    } catch (_) {}

    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && DateTime.now().toUtc().difference(last.timestamp.toUtc()).abs() < _maxLastKnownAge) {
        return last;
      }
    } catch (_) {}

    _report(hireIds, 'Waiting for GPS', 'No location fix yet — still trying.');
    return null;
  }

  Future<Position> _currentPosition(LocationAccuracy accuracy, Duration timeLimit) {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy, timeLimit: timeLimit),
    );
  }

  /// The phone's own timestamp for the fix, unless it's implausible (a wrong
  /// clock, a mocked location) — then "now".
  DateTime _fixTime(Position position) {
    final now = DateTime.now().toUtc();
    final taken = position.timestamp.toUtc();

    return taken.isAfter(now.subtract(const Duration(minutes: 3))) && taken.isBefore(now.add(const Duration(minutes: 1)))
        ? taken
        : now;
  }

  Future<void> _savePending() => FlutterForegroundTask.saveData(key: _pendingPointsKey, value: _pending.encode());

  void _report(Set<int> hireIds, String title, String text) {
    unawaited(FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: '${BackgroundTracking._hireLabel(hireIds)} · $text',
    ));
    FlutterForegroundTask.sendDataToMain({'type': 'error', 'message': text});
  }
}
