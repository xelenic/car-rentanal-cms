import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hire.dart';
import '../models/hire_map_targets.dart';
import '../models/hire_stage.dart';
import '../models/tracking_status.dart';
import '../services/api_client.dart';
import '../services/arrival_detector.dart';
import '../services/background_tracking.dart';
import '../services/pickup_store.dart';
import '../theme/app_theme.dart';
import '../widgets/background_access_prompt.dart';
import '../widgets/hire_map.dart';
import 'expense_entry_screen.dart';
import 'placeholder_screen.dart';

/// Google Maps' consumer directions deep link accepts at most 25 points
/// (origin + destination + waypoints) — evenly sample down to that cap,
/// always keeping the first and last point, rather than truncating the
/// trip or failing on a long one.
List<TrackPoint> _decimateTrackPoints(List<TrackPoint> points, int max) {
  if (points.length <= max) return points;
  final step = (points.length - 1) / (max - 1);
  final picked = <TrackPoint>[points.first];
  for (var i = 1; i < max - 1; i++) {
    picked.add(points[(i * step).round()]);
  }
  picked.add(points.last);
  return picked;
}

/// Shared copy for a hire that can't be started/completed yet because its
/// scheduled date hasn't arrived — used by both the tracking error banner
/// and the bottom complete bar so the wording matches everywhere.
String _scheduledMessage(Hire hire) {
  final formatted = DateFormat('MMM d, y  h:mm a').format(hire.startTime!.toLocal());
  return 'Scheduled for $formatted — can\'t start until then.';
}

class HireDetailScreen extends StatefulWidget {
  final Hire hire;

  /// Where the driver's "Pickup" mark is remembered. Only tests replace it.
  final PickupStore? pickupStore;

  /// The phone's position updates used to notice arrival at the pickup
  /// location. Only tests replace it (the default uses the device's GPS).
  final Stream<Position> Function()? positionStream;

  /// Opens a Google Maps link. Only tests replace it (the default hands the
  /// link to the Maps app or the browser).
  final Future<bool> Function(Uri url)? launchMapsUrl;

  /// Loads the path recorded so far for a hire that has been started. Only
  /// tests replace it (the default asks the server).
  final Future<TrackingStatus> Function(int hireId)? loadTracking;

  const HireDetailScreen({
    super.key,
    required this.hire,
    this.pickupStore,
    this.positionStream,
    this.launchMapsUrl,
    this.loadTracking,
  });

  @override
  State<HireDetailScreen> createState() => _HireDetailScreenState();
}

class _HireDetailScreenState extends State<HireDetailScreen> with WidgetsBindingObserver {
  late Hire _hire;
  Timer? _timer;
  bool _busy = false;
  String? _trackingError;
  List<TrackPoint> _points = [];

  /// What the phone currently allows for tracking to survive the app being
  /// minimized (null until first checked, or when it doesn't apply).
  BackgroundAccess? _access;

  late final PickupStore _pickupStore;

  /// The driver has tapped "Pickup" for this hire (null until read from the
  /// phone's storage, so the first frame doesn't flash the wrong button).
  bool? _pickedUp;

  /// Arrival at the pickup location — see [_syncArrivalWatch].
  final ArrivalDetector _arrival = ArrivalDetector();
  StreamSubscription<Position>? _positionSub;
  double? _metersToPickup;

  bool get _arrived => _arrival.arrived && !_hire.isScheduledInFuture;

  HireStage get _stage => hireStageOf(_hire, pickedUp: _pickedUp ?? false);

  @override
  void initState() {
    super.initState();
    _hire = widget.hire;
    _pickupStore = widget.pickupStore ?? const SecurePickupStore();
    _loadPickedUp();
    _loadPath();
    WidgetsBinding.instance.addObserver(this);
    BackgroundTracking.addListener(_onTrackingUpdate);
    if (_hire.isTracking) {
      _resumeTracking();
      _refreshAccess();
    }
  }

  /// Coming back to the app — from Settings after changing a permission, or
  /// after it sat in the background — re-checks the phone's settings and
  /// revives the service if the phone killed it meanwhile.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // The arrival highlight only matters while the driver is looking at
      // the screen — don't keep the GPS busy behind another app.
      unawaited(_stopArrivalWatch());
      return;
    }
    if (state != AppLifecycleState.resumed) return;

    unawaited(_syncArrivalWatch());
    if (!_hire.isTracking) return;

    unawaited(BackgroundTracking.ensureRunning());
    _refreshAccess();
  }

  /// The path driven so far, for the map — fetched when the hire opens so it
  /// shows straight away (and on a completed hire) instead of after the next
  /// position ping. A hire that was never started has none. Failing to load it
  /// (offline, a server without this endpoint) only means no path is drawn.
  Future<void> _loadPath() async {
    if (_hire.trackingStartedAt == null) return;

    try {
      final status = await (widget.loadTracking ?? ApiClient.instance.fetchTrackingStatus)(_hire.id);
      if (!mounted) return;

      // A ping may have delivered a fresher path while this was loading.
      if (status.points.length >= _points.length) {
        setState(() => _points = status.points);
      }
    } catch (_) {}
  }

  Future<void> _loadPickedUp() async {
    final pickedUp = await _pickupStore.isPickedUp(_hire.id);
    if (!mounted) return;

    setState(() => _pickedUp = pickedUp);
    unawaited(_syncArrivalWatch());
  }

  /// "Pickup": the driver is on the way to collect the customer. Remembered on
  /// the phone, reveals the Start button, and (asking for location permission
  /// if it isn't granted yet) starts watching for arrival at the pickup
  /// location so Start can light up when the driver gets there.
  Future<void> _pickup() async {
    if (_busy) return;

    await _pickupStore.markPickedUp(_hire.id);
    if (!mounted) return;

    setState(() {
      _pickedUp = true;
      _trackingError = null;
    });
    unawaited(_syncArrivalWatch(requestPermission: true));
  }

  /// Watches the phone's position while the Start button is showing, so the
  /// button can highlight itself on arrival. Runs only in the Start stage, only
  /// for hires whose pickup location has coordinates, and stops otherwise.
  Future<void> _syncArrivalWatch({bool requestPermission = false}) async {
    final wanted = mounted && _stage == HireStage.start && _hire.hasPickupCoordinates;
    if (!wanted) {
      await _stopArrivalWatch();
      return;
    }
    if (_positionSub != null) return;

    final Stream<Position>? stream = widget.positionStream != null
        ? widget.positionStream!()
        : await _openPositionStream(requestPermission: requestPermission);
    if (stream == null || !mounted || _positionSub != null) return;

    // Errors (GPS switched off mid-way, …) just mean no highlight.
    _positionSub = stream.listen(_onPosition, onError: (_) {});
  }

  Future<void> _stopArrivalWatch() async {
    final sub = _positionSub;
    _positionSub = null;
    await sub?.cancel();

    _arrival.reset();
    if (mounted && (_metersToPickup != null)) {
      setState(() => _metersToPickup = null);
    }
  }

  Future<Stream<Position>?> _openPositionStream({required bool requestPermission}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
      );
    } catch (_) {
      return null;
    }
  }

  void _onPosition(Position position) {
    if (!mounted || !_hire.hasPickupCoordinates) return;

    final meters = distanceMeters(
      position.latitude,
      position.longitude,
      _hire.pickupLatitude!,
      _hire.pickupLongitude!,
    );
    final changed = _arrival.update(meters);

    setState(() => _metersToPickup = meters);
    if (changed && _arrived) {
      // Once, the moment the driver gets there — the screen may not be in view.
      HapticFeedback.heavyImpact().catchError((_) {});
    }
  }

  Future<void> _refreshAccess() async {
    if (!backgroundTrackingSupported) return;

    final access = await BackgroundTracking.checkAccess();
    if (mounted) setState(() => _access = access);
  }

  /// Asks for the phone settings that keep tracking alive in the background
  /// (see [offerBackgroundAccess]), then refreshes the reminder.
  Future<void> _offerAccess() async {
    if (!backgroundTrackingSupported || !mounted) return;

    await offerBackgroundAccess(context);
    await _refreshAccess();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Only this screen's own listener/timer go away. The Android background
    // service is deliberately left running — it's what keeps tracking after
    // the driver leaves this screen or minimizes the app, and only ends when
    // the hire is stopped or completed.
    BackgroundTracking.removeListener(_onTrackingUpdate);
    _timer?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  /// The in-app fallback (web/other platforms, or if the Android service
  /// can't start): only records while this screen is open.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(kTrackingPingInterval, (_) => _captureAndSendPoint());
  }

  /// Starts whatever keeps recording positions for an active hire: the
  /// Android background service when available, otherwise the in-app timer.
  Future<void> _beginTrackingLoop() async {
    if (!backgroundTrackingSupported) {
      _startTimer();
      return;
    }

    final started = await BackgroundTracking.start(_hire.id);
    if (started) {
      _timer?.cancel();
      return;
    }

    _startTimer();
    if (mounted) {
      setState(() {
        _trackingError =
            'Background tracking could not start, so location is only recorded while this screen stays open.';
      });
    }
  }

  /// Re-attaches tracking when the screen opens for a hire that's already
  /// active — e.g. the app was closed and reopened, or the OS killed the
  /// service. The service just keeps running if it's still alive.
  Future<void> _resumeTracking() => _beginTrackingLoop();

  /// Ends whichever recorder is running for this hire: the in-app timer and
  /// (on Android) the background service, which also removes its pinned
  /// notification once no hire is left.
  Future<void> _endTrackingLoop() async {
    _timer?.cancel();
    await BackgroundTracking.stop(_hire.id);
  }

  /// Messages from the Android background service (see BackgroundTracking):
  /// a fresh status for a hire it just recorded a position for, or an error
  /// worth surfacing (GPS off, server unreachable).
  void _onTrackingUpdate(Object data) {
    if (!mounted || data is! Map) return;

    final message = Map<String, dynamic>.from(data);

    if (message['type'] == 'error') {
      setState(() => _trackingError = message['message'] as String?);
      return;
    }

    if (message['type'] != 'status' || message['hire_id'] != _hire.id) return;

    final status = TrackingStatus.fromJson(message);
    setState(() {
      _hire = _hire.copyWith(
        status: status.status,
        statusLabel: status.statusLabel,
        isTracking: status.isTracking,
        trackingStoppedAt: status.trackingStoppedAt,
        totalDistanceKm: status.totalDistanceKm,
      );
      _points = status.points;
      _trackingError = null;
    });
  }

  Future<Position> _getCurrentPosition() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission is required to track this hire.');
    }

    return Geolocator.getCurrentPosition(
      // Never spin forever waiting for a fix — after this the driver gets an
      // error and can tap Start again.
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 20)),
    );
  }

  Future<void> _captureAndSendPoint() async {
    try {
      final position = await _getCurrentPosition();
      final status = await ApiClient.instance.sendTrackingPoint(
        _hire.id,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      if (!mounted) return;
      setState(() {
        _hire = _hire.copyWith(totalDistanceKm: status.totalDistanceKm);
        _points = status.points;
        _trackingError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _trackingError = e.toString());
    }
  }

  /// Opens the path recorded so far as a route in Google Maps (the app if
  /// installed, otherwise the browser) — a single point opens as a plain
  /// location instead of a route, since there's nothing to route between.
  Future<void> _openPathInMaps() async {
    if (_points.isEmpty) return;

    final Uri url;
    if (_points.length == 1) {
      final p = _points.first;
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.lat},${p.lng}');
    } else {
      final sampled = _decimateTrackPoints(_points, 25);
      final origin = sampled.first;
      final destination = sampled.last;
      final waypoints = sampled.sublist(1, sampled.length - 1);
      final waypointsParam = waypoints.map((p) => '${p.lat},${p.lng}').join('|');

      url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${origin.lat},${origin.lng}'
        '&destination=${destination.lat},${destination.lng}'
        '${waypointsParam.isEmpty ? '' : '&waypoints=$waypointsParam'}'
        '&travelmode=driving',
      );
    }

    await _launchMapsUrl(url);
  }

  /// Opens a place by name in Google Maps — the address the customer booked,
  /// not the GPS trail (that only exists once the driver has pressed Start; see
  /// [_openPathInMaps]).
  Future<void> _openAddressInMaps(String address) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}');
    await _launchMapsUrl(url);
  }

  Future<void> _launchMapsUrl(Uri url) async {
    try {
      final launched = widget.launchMapsUrl != null
          ? await widget.launchMapsUrl!(url)
          : await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        setState(() => _trackingError = 'Could not open Google Maps.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _trackingError = 'Could not open Google Maps: $e');
    }
  }

  Future<void> _toggleTracking() async {
    if (_hire.isCompleted) return;

    if (!_hire.isTracking && _hire.isScheduledInFuture) {
      setState(() => _trackingError = _scheduledMessage(_hire));
      return;
    }

    setState(() {
      _busy = true;
      _trackingError = null;
    });

    try {
      if (_hire.isTracking) {
        final status = await ApiClient.instance.stopTracking(_hire.id);
        await _endTrackingLoop();
        if (!mounted) return;
        setState(() {
          _hire = _hire.copyWith(
            isTracking: false,
            trackingStoppedAt: status.trackingStoppedAt,
            totalDistanceKm: status.totalDistanceKm,
          );
          _points = status.points;
        });
      } else {
        // Starting: the arrival highlight has done its job, and the GPS is
        // needed for the first point.
        await _stopArrivalWatch();
        final position = await _getCurrentPosition();
        await BackgroundTracking.requestNotificationPermission();
        final status = await ApiClient.instance.startTracking(_hire.id);
        final pointStatus = await ApiClient.instance.sendTrackingPoint(
          _hire.id,
          latitude: position.latitude,
          longitude: position.longitude,
        );

        if (!mounted) return;
        setState(() {
          _hire = _hire.copyWith(
            status: status.status,
            statusLabel: status.statusLabel,
            isTracking: true,
            trackingStartedAt: status.trackingStartedAt,
            totalDistanceKm: pointStatus.totalDistanceKm,
          );
          _points = pointStatus.points;
        });
        await _beginTrackingLoop();
        // With the service already running (so it isn't started from the
        // background while Settings is open), ask for the phone settings
        // that keep it alive once another app is opened.
        unawaited(_offerAccess());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _trackingError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmComplete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Complete this hire?',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'This stops tracking and marks the hire as completed. It cannot be started again afterwards.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _completeHire();
    }
  }

  Future<void> _completeHire() async {
    setState(() {
      _busy = true;
      _trackingError = null;
    });

    try {
      final status = await ApiClient.instance.completeHire(_hire.id);
      await _endTrackingLoop();
      await _pickupStore.clear(_hire.id);
      if (!mounted) return;
      setState(() {
        _hire = _hire.copyWith(
          status: status.status,
          statusLabel: status.statusLabel,
          isTracking: false,
          trackingStoppedAt: status.trackingStoppedAt,
          totalDistanceKm: status.totalDistanceKm,
        );
        _points = status.points;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _trackingError = "Couldn't get your location. Check that GPS is on, then try again.");
    } catch (e) {
      if (!mounted) return;
      setState(() => _trackingError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
      unawaited(_syncArrivalWatch());
    }
  }

  void _openShortcut(String title, IconData icon) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PlaceholderScreen(title: title, icon: icon)),
    );
  }

  void _openExpense(String category, String title, bool receiptRequired) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseEntryScreen(
          hire: _hire,
          category: category,
          title: title,
          receiptRequired: receiptRequired,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d, y  h:mm a');
    final hire = _hire;
    final mapTargets = mapTargetsOf(hire);
    final nextTarget = mapTargetFor(hire, _stage);
    final route = mapRouteFor(hire, _stage);

    return Scaffold(
      appBar: AppBar(title: Text('Hire #${hire.id}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TrackingCard(
            hire: hire,
            stage: _stage,
            stageLoading: _pickedUp == null && _stage == HireStage.pickup,
            busy: _busy,
            error: _trackingError,
            hasPath: _points.isNotEmpty,
            arrived: _arrived,
            metersToPickup: _metersToPickup,
            mapRoute: route,
            onOpenRoute: (route) => _launchMapsUrl(route.url),
            accessNotice: backgroundAccessNotice(_access),
            onPickup: _pickup,
            onStart: _toggleTracking,
            onStop: _toggleTracking,
            onComplete: _confirmComplete,
            onViewPath: _openPathInMaps,
            onFixAccess: _offerAccess,
          ),
          const SizedBox(height: 12),
          HireMapCard(hireId: hire.id, places: hire.mapPoints, path: _points),
          const SizedBox(height: 12),
          _QuickActionsRow(
            onOpen: _openShortcut,
            onExpense: _openExpense,
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Tour',
            children: [
              _InfoRow(label: 'Type', value: hire.tourTypeLabel),
              if (hire.tourType == 'package' && hire.package != null)
                _InfoRow(label: 'Package', value: hire.package!),
              if (hire.tourType != 'multi_day' && hire.tourType != 'package') ...[
                _InfoRow(label: 'From', value: hire.fromLocation ?? '—'),
                _InfoRow(label: 'To', value: hire.toLocation ?? '—'),
              ],
              if (hire.stayLocations.isNotEmpty)
                _InfoRow(
                  label: hire.tourType == 'multi_day' ? 'Locations' : 'Stay Locations',
                  value: hire.stayLocations.join(', '),
                ),
              if (hire.startTime != null)
                _InfoRow(label: 'Start', value: dateFormat.format(hire.startTime!.toLocal())),
              if (hire.endTime != null)
                _InfoRow(label: 'End', value: dateFormat.format(hire.endTime!.toLocal())),
              // One button per place — pickup and end (and any stops) are
              // separate; the one the driver is heading for now is filled in.
              if (mapTargets.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final target in mapTargets)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MapsButton.place(
                      target: target,
                      primary: target == nextTarget,
                      onTap: () => _openAddressInMaps(target.place),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Vehicle & Payment',
            children: [
              _InfoRow(label: 'Vehicle', value: hire.vehicle ?? '—'),
              _InfoRow(
                label: 'Total Value',
                value: 'Rs. ${hire.hireFullValue.toStringAsFixed(2)}',
              ),
              _InfoRow(label: 'Payment Method', value: hire.paymentTypeLabel),
            ],
          ),
          if (hire.description != null && hire.description!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _SectionCard(
              title: 'Description',
              children: [
                Text(
                  hire.description!,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                ),
              ],
            ),
          ],
        ],
      ),
      // Completing a hire happens on the tracking card (next to Stop); the
      // bar is only left to confirm a hire that's already done.
      bottomNavigationBar: hire.isCompleted
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: _CompleteBar(hire: hire),
            )
          : null,
    );
  }
}

/// Shown at the bottom of a hire that's already been completed.
class _CompleteBar extends StatelessWidget {
  final Hire hire;

  const _CompleteBar({required this.hire});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.neon.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.neon.withValues(alpha: 0.4)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, color: AppColors.neon, size: 18),
          SizedBox(width: 8),
          Text(
            'Hire Completed',
            style: TextStyle(
              color: AppColors.neon,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// The hire's action area, one of three scenarios (see [HireStage]):
///
///  1. before the hire starts — a "Pickup" button;
///  2. once picked up — the "Start" button, which highlights itself when the
///     driver reaches the hire's assigned location;
///  3. while the hire runs — "Stop" and "Complete" buttons.
class _TrackingCard extends StatelessWidget {
  final Hire hire;
  final HireStage stage;

  /// The saved "picked up" mark hasn't been read yet — show a spinner instead
  /// of a button that might turn out to be the wrong one.
  final bool stageLoading;
  final bool busy;
  final String? error;
  final bool hasPath;

  /// The phone is at the pickup location (only ever true in the Start stage).
  final bool arrived;
  final double? metersToPickup;

  /// The Google Maps route for this stage — Your location → pickup → end
  /// before the hire starts, Your location → end once it has — or null when
  /// there is nothing to navigate to.
  final MapRoute? mapRoute;
  final ValueChanged<MapRoute> onOpenRoute;

  /// Reminder that the phone's settings may stop tracking once another app
  /// is opened (see backgroundAccessNotice); null when nothing needs fixing.
  final String? accessNotice;
  final VoidCallback onPickup;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onComplete;
  final VoidCallback onViewPath;
  final VoidCallback onFixAccess;

  const _TrackingCard({
    required this.hire,
    required this.stage,
    required this.stageLoading,
    required this.busy,
    required this.error,
    required this.hasPath,
    required this.arrived,
    required this.metersToPickup,
    required this.mapRoute,
    required this.onOpenRoute,
    required this.accessNotice,
    required this.onPickup,
    required this.onStart,
    required this.onStop,
    required this.onComplete,
    required this.onViewPath,
    required this.onFixAccess,
  });

  bool get _isPaused => stage == HireStage.start && hire.trackingStartedAt != null;

  /// A future-dated hire can be picked up early (the driver has to set off
  /// before the scheduled time) but not started until its date arrives.
  bool get _startLocked => stage == HireStage.start && hire.isScheduledInFuture;

  String get _statusText {
    switch (stage) {
      case HireStage.completed:
        return 'Completed';
      case HireStage.inProgress:
        return 'Tracking active';
      case HireStage.start:
        if (_isPaused) return 'Tracking paused';
        if (_startLocked) return 'Scheduled — not startable yet';
        return arrived ? 'You have arrived' : 'Ready to start';
      case HireStage.pickup:
        return 'Not started';
    }
  }

  static String _distance(double meters) =>
      meters < 1000 ? '${meters.round()} m' : '${(meters / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    final isTracking = stage == HireStage.inProgress;
    final showScheduleNote = (stage == HireStage.pickup || stage == HireStage.start) && hire.isScheduledInFuture;
    final place = hire.pickupLocationName;

    final VoidCallback? circleTap;
    switch (stage) {
      case HireStage.pickup:
        circleTap = onPickup;
      case HireStage.start:
        circleTap = onStart;
      case HireStage.inProgress:
      case HireStage.completed:
        circleTap = null;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isTracking) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: AppColors.neon,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                _statusText,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _PulseStartButton(
            stage: stage,
            isLocked: _startLocked,
            arrived: arrived,
            busy: busy || stageLoading,
            distanceKm: hire.totalDistanceKm,
            onTap: circleTap,
          ),
          if (stage == HireStage.pickup) ...[
            const SizedBox(height: 12),
            _StageHint(
              icon: Icons.directions_car_outlined,
              color: AppColors.textSecondary,
              text: place != null
                  ? 'Tap Pickup when you set off to collect the customer at $place.'
                  : 'Tap Pickup when you set off to collect the customer.',
            ),
          ],
          if (stage == HireStage.start && !_startLocked) ...[
            const SizedBox(height: 12),
            if (arrived)
              _StageHint(
                icon: Icons.place,
                color: _arrivedColor,
                strong: true,
                text: place != null
                    ? "You've arrived at $place — tap Start."
                    : "You've arrived — tap Start.",
              )
            else if (_isPaused)
              const _StageHint(
                icon: Icons.pause_circle_outline,
                color: AppColors.textSecondary,
                text: 'Tracking is paused — tap Start to resume.',
              )
            else if (hire.hasPickupCoordinates && metersToPickup != null)
              _StageHint(
                icon: Icons.near_me_outlined,
                color: AppColors.textSecondary,
                text: '${place ?? 'Pickup'} is ${_distance(metersToPickup!)} away — Start lights up when you arrive.',
              )
            else
              const _StageHint(
                icon: Icons.play_circle_outline,
                color: AppColors.textSecondary,
                text: 'Tap Start when you reach the pickup location.',
              ),
          ],
          if (stage == HireStage.inProgress) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onStop,
                    icon: const Icon(Icons.stop_circle_outlined, size: 20),
                    label: const Text('Stop'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: BorderSide(color: busy ? AppColors.border : AppColors.danger),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _CompleteButton(busy: busy, onPressed: onComplete),
                ),
              ],
            ),
          ],
          // Paused (started once, then stopped): Start resumes, and the hire
          // can still be completed without starting it again.
          if (_isPaused) ...[
            const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: _CompleteButton(busy: busy, onPressed: onComplete)),
          ],
          if (mapRoute != null) ...[
            const SizedBox(height: 14),
            _MapsButton.route(route: mapRoute!, onTap: () => onOpenRoute(mapRoute!)),
          ],
          if (isTracking && accessNotice != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(Icons.battery_alert_outlined, color: AppColors.warning, size: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          accessNotice!,
                          style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, height: 1.3),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: onFixAccess,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: AppColors.neonDeep,
                            ),
                            child: const Text('Fix now', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (hasPath) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onViewPath,
                icon: const Icon(Icons.map_outlined, size: 18),
                label: const Text('View Path in Google Maps'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.neonDeep,
                  side: const BorderSide(color: AppColors.neon),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          if (showScheduleNote) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_clock_outlined, color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _scheduledMessage(hire),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _StatBlock(
                  icon: Icons.payments_outlined,
                  label: 'Payment Method',
                  value: hire.paymentTypeLabel,
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The green used for "you've arrived" — the Start button turns this colour.
const _arrivedColor = Color(0xFF16A34A);

/// A Google Maps button with a title and, underneath, what it will open.
/// [primary] fills it in; otherwise it's outlined.
///
///  * [_MapsButton.route] — the whole trip, "You → pickup → end";
///  * [_MapsButton.place] — one place, "Open <pickup location | end location |
///    stop N> in Google Maps"; filled in for the place the driver is heading
///    for now.
class _MapsButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;

  const _MapsButton._({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
  });

  factory _MapsButton.route({required MapRoute route, required VoidCallback onTap}) => _MapsButton._(
        icon: Icons.alt_route,
        title: 'Open route in Google Maps',
        subtitle: route.summary,
        primary: true,
        onTap: onTap,
      );

  factory _MapsButton.place({required MapTarget target, required bool primary, required VoidCallback onTap}) {
    final IconData icon;
    switch (target.role) {
      case MapRole.pickup:
        icon = Icons.trip_origin;
      case MapRole.end:
        icon = Icons.flag_outlined;
      case MapRole.stop:
        icon = Icons.pin_drop_outlined;
      case MapRole.single:
        icon = Icons.location_on_outlined;
    }

    return _MapsButton._(
      icon: icon,
      title: 'Open ${target.label.toLowerCase()} in Google Maps',
      subtitle: target.place,
      primary: primary,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? AppColors.onNeon : AppColors.neonDeep;

    return Material(
      color: primary ? AppColors.neon : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.neon),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Icon(icon, color: foreground, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: foreground.withValues(alpha: primary ? 0.9 : 0.75), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Icon(Icons.open_in_new, color: foreground, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// A line of guidance under the main button.
class _StageHint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final bool strong;

  const _StageHint({required this.icon, required this.color, required this.text, this.strong = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: strong ? color.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: strong ? Border.all(color: color.withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: strong ? AppColors.textPrimary : AppColors.textSecondary,
                fontSize: 12.5,
                height: 1.3,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Complete Hire" — asks for confirmation (see _confirmComplete) before
/// anything is sent.
class _CompleteButton extends StatelessWidget {
  final bool busy;
  final VoidCallback onPressed;

  const _CompleteButton({required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: const Icon(Icons.check_circle_outline, size: 20),
      label: const Text('Complete Hire'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neon,
        foregroundColor: AppColors.onNeon,
        disabledBackgroundColor: AppColors.surfaceElevated,
        disabledForegroundColor: AppColors.textMuted,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Large centered "record button"-style meter that is the hire's main action:
/// "Pickup" (blue) before the hire starts, "Start" (red) once picked up, and —
/// while it runs — the live distance readout with ripples (Stop and Complete
/// are separate buttons under it).
///
/// It breathes to invite a tap. When the driver reaches the hire's assigned
/// location ([arrived]) the Start button highlights itself: it turns green,
/// pulses faster and sends out ripples until it's tapped.
class _PulseStartButton extends StatefulWidget {
  final HireStage stage;
  final bool isLocked;
  final bool arrived;
  final bool busy;
  final double distanceKm;

  /// Null when the button isn't tappable in this stage (tracking, completed).
  final VoidCallback? onTap;

  const _PulseStartButton({
    required this.stage,
    required this.isLocked,
    required this.arrived,
    required this.busy,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  State<_PulseStartButton> createState() => _PulseStartButtonState();
}

class _PulseStartButtonState extends State<_PulseStartButton> with TickerProviderStateMixin {
  static const _calmBreath = Duration(milliseconds: 1100);
  static const _arrivedBreath = Duration(milliseconds: 600);
  static const _calmRipple = Duration(milliseconds: 1600);
  static const _arrivedRipple = Duration(milliseconds: 1200);

  late final AnimationController _breathController;
  late final AnimationController _rippleController;

  bool get _isTracking => widget.stage == HireStage.inProgress;
  bool get _isCompleted => widget.stage == HireStage.completed;
  bool get _highlighted => widget.arrived && widget.stage == HireStage.start && !widget.isLocked;
  bool get _shouldBreathe => !_isCompleted && !_isTracking && !widget.isLocked;
  bool get _shouldRipple => _isTracking || _highlighted;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(vsync: this, duration: _highlighted ? _arrivedBreath : _calmBreath);
    _rippleController = AnimationController(vsync: this, duration: _highlighted ? _arrivedRipple : _calmRipple);
    if (_shouldBreathe) _breathController.repeat(reverse: true);
    if (_shouldRipple) _rippleController.repeat();
  }

  @override
  void didUpdateWidget(covariant _PulseStartButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Highlighting switches the tempo, so restart the loops with the new one.
    _breathController.duration = _highlighted ? _arrivedBreath : _calmBreath;
    _rippleController.duration = _highlighted ? _arrivedRipple : _calmRipple;

    if (!_shouldBreathe) {
      _breathController.stop();
      _breathController.value = 0;
    } else if (!_breathController.isAnimating || oldWidget.arrived != widget.arrived) {
      _breathController.repeat(reverse: true);
    }

    if (!_shouldRipple) {
      _rippleController.stop();
      _rippleController.reset();
    } else if (!_rippleController.isAnimating || oldWidget.arrived != widget.arrived) {
      _rippleController.repeat();
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  Color get _color {
    if (_isCompleted) return AppColors.neon;
    if (widget.isLocked) return AppColors.textMuted;
    if (widget.stage == HireStage.pickup) return AppColors.neonDeep;
    if (_highlighted) return _arrivedColor;
    return AppColors.danger;
  }

  String get _pillText {
    switch (widget.stage) {
      case HireStage.pickup:
        return 'PICKUP';
      case HireStage.start:
        return _highlighted ? 'TAP TO START' : 'START';
      case HireStage.inProgress:
        return 'TRACKING';
      case HireStage.completed:
        return 'DONE';
    }
  }

  @override
  Widget build(BuildContext context) {
    const size = 188.0;
    final color = _color;
    final canTap = widget.onTap != null && !widget.isLocked && !widget.busy;
    final rings = _highlighted ? 3 : 2;
    final ringColor = _highlighted ? _arrivedColor : AppColors.danger;

    return Center(
      child: GestureDetector(
        onTap: canTap ? widget.onTap : null,
        child: SizedBox(
          width: size + 56,
          height: size + 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (_shouldRipple)
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: List.generate(rings, (i) {
                        final t = (_rippleController.value + (i / rings)) % 1.0;
                        return Opacity(
                          opacity: (1 - t) * (_highlighted ? 0.7 : 0.45),
                          child: Container(
                            width: size + t * 56,
                            height: size + t * 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: ringColor, width: _highlighted ? 3 : 2),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),
              AnimatedBuilder(
                animation: _breathController,
                builder: (context, child) {
                  final amount = _highlighted ? 0.09 : 0.045;
                  final scale = _shouldBreathe ? 1.0 + (_breathController.value * amount) : 1.0;
                  return Transform.scale(scale: scale, child: child);
                },
                // Colour changes (Pickup blue → Start red → arrived green)
                // fade instead of jumping.
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.95),
                        color.withValues(alpha: 0.78),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: _highlighted ? 0.7 : 0.45),
                        blurRadius: _highlighted ? 44 : 30,
                        spreadRadius: _highlighted ? 6 : 2,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: widget.busy
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
                        )
                      : widget.isLocked
                          ? const Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline, color: Colors.white, size: 40),
                                SizedBox(height: 10),
                                Text(
                                  'LOCKED',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.stage == HireStage.pickup) ...[
                                  const Icon(Icons.directions_car_filled_outlined, color: Colors.white, size: 52),
                                  const SizedBox(height: 12),
                                ] else ...[
                                  Text(
                                    widget.distanceKm.toStringAsFixed(1),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 40,
                                      fontWeight: FontWeight.w800,
                                      height: 1,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'KM',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    _pillText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatBlock({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.neon, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                label,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final void Function(String title, IconData icon) onOpen;
  final void Function(String category, String title, bool receiptRequired) onExpense;

  const _QuickActionsRow({required this.onOpen, required this.onExpense});

  static const _actions = <_ShortcutAction>[
    _ShortcutAction('Fuel', Icons.local_gas_station_outlined, 'Fuel Cost', AppColors.neon, category: 'fuel'),
    _ShortcutAction('Repair', Icons.car_repair_outlined, 'Vehicle Repair', AppColors.neon),
    _ShortcutAction('Emergency', Icons.emergency_outlined, 'Emergency', AppColors.danger),
    _ShortcutAction('Highway', Icons.toll_outlined, 'Highway Charges', AppColors.neon,
        category: 'highway', receiptRequired: false),
    _ShortcutAction('Foods', Icons.restaurant_outlined, 'Driver Foods', AppColors.neon,
        category: 'food', receiptRequired: false),
    _ShortcutAction('Rooms', Icons.hotel_outlined, 'Room Charges', AppColors.neon,
        category: 'room', receiptRequired: false),
    _ShortcutAction('Parking', Icons.local_parking_outlined, 'Parking Tickets', AppColors.neon,
        category: 'parking', receiptRequired: false),
    _ShortcutAction('Others', Icons.more_horiz_outlined, 'Others', AppColors.neon),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _actions
            .map(
              (action) => Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _QuickActionCircle(
                  icon: action.icon,
                  label: action.label,
                  color: action.color,
                  onTap: action.category != null
                      ? () => onExpense(action.category!, action.title, action.receiptRequired)
                      : () => onOpen(action.title, action.icon),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ShortcutAction {
  final String label;
  final IconData icon;
  final String title;
  final Color color;
  final String? category;
  final bool receiptRequired;

  const _ShortcutAction(
    this.label,
    this.icon,
    this.title,
    this.color, {
    this.category,
    this.receiptRequired = true,
  });
}

class _QuickActionCircle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCircle({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.neon,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
