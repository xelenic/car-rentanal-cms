import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/hire_map_point.dart';
import '../models/map_role.dart';
import '../models/tracking_status.dart';
import '../services/arrival_detector.dart' show distanceMeters;
import '../services/route_planner.dart';
import '../theme/app_theme.dart';
import 'map_pins.dart';

/// Where the map looks when a hire has nothing to plot yet: the middle of Sri
/// Lanka, zoomed out to the whole island.
const LatLng kDefaultMapCenter = LatLng(7.8731, 80.7718);

double _markerHue(MapRole role) {
  switch (role) {
    case MapRole.pickup:
      return BitmapDescriptor.hueGreen;
    case MapRole.end:
      return BitmapDescriptor.hueRed;
    case MapRole.stop:
      return BitmapDescriptor.hueOrange;
    case MapRole.single:
      return BitmapDescriptor.hueViolet;
  }
}

/// One marker per place; tapping it shows what it is and its name. [pins] are
/// the drawn pin pictures (see [MapPins]); until they are ready — or where
/// they can't be drawn — the map's plain hue-tinted markers stand in.
Set<Marker> hireMarkers(
  List<HireMapPoint> places, {
  Map<MapRole, BitmapDescriptor> pins = const {},
  LatLng? me,
  BitmapDescriptor? meIcon,
}) {
  return {
    // The driver's own position — drawn as a marker (not the map's built-in
    // blue dot, which the web map doesn't have) so it looks the same everywhere.
    if (me != null)
      Marker(
        markerId: const MarkerId('you'),
        position: me,
        icon: meIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 2,
        infoWindow: const InfoWindow(title: 'You'),
      ),
    for (var i = 0; i < places.length; i++)
      Marker(
        markerId: MarkerId('${places[i].role.name}-$i'),
        position: LatLng(places[i].latitude, places[i].longitude),
        icon: pins[places[i].role] ?? BitmapDescriptor.defaultMarkerWithHue(_markerHue(places[i].role)),
        infoWindow: InfoWindow(title: places[i].label, snippet: places[i].name),
      ),
  };
}

/// A trip of many thousand fixes would make the map crawl — the line keeps
/// its shape with far fewer, always keeping the first and last point.
List<TrackPoint> thinPath(List<TrackPoint> path, {int max = 400}) {
  if (path.length <= max) return path;

  final step = (path.length - 1) / (max - 1);
  return [
    for (var i = 0; i < max - 1; i++) path[(i * step).round()],
    path.last,
  ];
}

/// The line the phone has driven so far.
Set<Polyline> hirePathLines(List<TrackPoint> path) {
  if (path.length < 2) return const {};

  return {
    Polyline(
      polylineId: const PolylineId('driven-path'),
      points: [for (final p in thinPath(path)) LatLng(p.lat, p.lng)],
      color: const Color(0xFF0D9488), // teal — distinct from the blue route ahead
      width: 5,
      zIndex: 2,
    ),
  };
}

/// Blue, like Google Maps' own route line.
const Color kRouteColor = Color(0xFF2563EB);

/// The route ahead, drawn beneath the driven path. A straight line (no road
/// route yet, or none possible) is dashed where the map supports it.
Set<Polyline> hireRouteLines(PlannedRoute? route) {
  if (route == null || route.points.length < 2) return const {};

  return {
    Polyline(
      polylineId: const PolylineId('planned-route'),
      points: route.points,
      color: kRouteColor,
      width: 6,
      zIndex: 1,
      patterns: route.approximate ? [PatternItem.dash(18), PatternItem.gap(12)] : const [],
    ),
  };
}

/// The smallest box holding all [points], or null when there is nothing to
/// frame or they are all the same spot (nothing to "fit" — the map should just
/// centre there).
LatLngBounds? boundsOf(Iterable<LatLng> points) {
  final list = points.toList();
  if (list.isEmpty) return null;

  var south = list.first.latitude, north = list.first.latitude;
  var west = list.first.longitude, east = list.first.longitude;
  for (final p in list) {
    if (p.latitude < south) south = p.latitude;
    if (p.latitude > north) north = p.latitude;
    if (p.longitude < west) west = p.longitude;
    if (p.longitude > east) east = p.longitude;
  }

  if (south == north && west == east) return null;
  return LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east));
}

/// [bounds] with extra room added along the top. Pins are drawn *above* the
/// spot they mark and the route chip sits over the top edge, so a place at the
/// top of the frame would otherwise have its pin hidden under the chip.
LatLngBounds withTopRoom(LatLngBounds bounds, {double fraction = 0.3}) {
  final south = bounds.southwest.latitude, north = bounds.northeast.latitude;
  final extended = (north + (north - south) * fraction).clamp(-85.0, 85.0);

  return LatLngBounds(southwest: bounds.southwest, northeast: LatLng(extended, bounds.northeast.longitude));
}

/// The driver's last known position, shared by every map on screen so a map
/// that opens (the full screen one) shows the driver at once instead of
/// waiting for its own first GPS fix. Ignored once it is this old.
LatLng? _lastKnownMe;
DateTime? _lastKnownMeAt;
const Duration _lastKnownMeMaxAge = Duration(minutes: 2);

/// Forgets the shared position — for tests, so one doesn't leak into the next.
@visibleForTesting
void resetSharedMyLocation() {
  _lastKnownMe = null;
  _lastKnownMeAt = null;
}

LatLng? _recentKnownMe() {
  final at = _lastKnownMeAt;
  if (_lastKnownMe == null || at == null) return null;
  return DateTime.now().difference(at) <= _lastKnownMeMaxAge ? _lastKnownMe : null;
}

/// A Google Map showing where the hire's places are (pickup, end, stops), the
/// path driven so far, and the driver's own position.
///
/// It frames everything when it opens; the buttons in the corner re-frame it
/// ("show all") or jump to the driver ("my location"). Inline in a scrolling
/// page it lets the page scroll over it — open it full screen
/// ([HireMapScreen]) to pan and zoom freely ([interactive]).
class HireMapView extends StatefulWidget {
  final List<HireMapPoint> places;
  final List<TrackPoint> path;

  /// Null fills the space the parent gives it.
  final double? height;

  /// Claims all touch gestures (pan/zoom) — for the full screen map.
  final bool interactive;

  /// The driver's position over time. Defaults to the phone's GPS; only tests
  /// supply their own.
  final Stream<LatLng>? locationOverride;

  /// What is still ahead of the driver, in order (see routeStopsFor). While
  /// this isn't empty and the driver's position is known, the map draws the
  /// route from the driver through these places to the last one.
  final List<HireMapPoint> routeStops;

  /// Plans the road route from the driver's position through [routeStops].
  /// Null, or a failure, leaves the straight-line view in place.
  final Future<PlannedRoute?> Function(LatLng origin)? planRoute;

  const HireMapView({
    super.key,
    required this.places,
    this.path = const [],
    this.height,
    this.interactive = false,
    this.locationOverride,
    this.routeStops = const [],
    this.planRoute,
  });

  @override
  State<HireMapView> createState() => _HireMapViewState();
}

class _HireMapViewState extends State<HireMapView> {
  GoogleMapController? _controller;

  /// The driver's own position (drawn on the map, used to frame it and for
  /// "my location"), kept current while the map is on screen.
  LatLng? _me;
  StreamSubscription<LatLng>? _meSub;
  BitmapDescriptor? _meIcon;

  /// The drawn pin pictures, filled in shortly after the map opens.
  final Map<MapRole, BitmapDescriptor> _pins = {};

  /// The route ahead: a straight line at once, replaced by the road route when
  /// it has been planned.
  PlannedRoute? _route;
  LatLng? _routeOrigin;
  DateTime? _routeAt;
  bool _planning = false;

  /// How far the driver has to move, and how long ago the route was last
  /// drawn, before it is planned again — every ping would be a billed call.
  static const double _replanMeters = 400;
  static const Duration _replanEvery = Duration(seconds: 45);

  bool get _hasData => widget.places.isNotEmpty || widget.path.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _me = _recentKnownMe();
    _loadPins();
    _loadMeIcon();
    _watchMe(askPermission: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshRoute());
  }

  Future<void> _loadMeIcon() async {
    try {
      final icon = await MapPins.you();
      if (mounted) setState(() => _meIcon = icon);
    } catch (_) {}
  }

  Future<void> _loadPins() async {
    for (final role in {for (final place in widget.places) place.role}) {
      try {
        final icon = await MapPins.forRole(role);
        if (!mounted) return;
        setState(() => _pins[role] = icon);
      } catch (_) {
        // can't draw here — the plain markers stay
      }
    }
  }

  @override
  void didUpdateWidget(covariant HireMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // New places (e.g. the hire was reloaded) → frame them again. A growing
    // path never re-frames: that would fight a driver who is looking around.
    if (!listEquals(oldWidget.places, widget.places)) {
      _loadPins();
      _fit();
    }

    // What is ahead changed (the hire was started: the pickup is now behind) →
    // draw the new route and frame it.
    if (!listEquals(oldWidget.routeStops, widget.routeStops)) {
      _route = null;
      _routeOrigin = null;
      _routeAt = null;
      _refreshRoute();
    }
  }

  @override
  void dispose() {
    _meSub?.cancel();
    // The controller is not disposed here: the GoogleMap widget disposes its own
    // when it goes away, and disposing it a second time throws on the web.
    super.dispose();
  }

  LatLng get _initialTarget {
    if (widget.places.isNotEmpty) return LatLng(widget.places.first.latitude, widget.places.first.longitude);
    if (widget.path.isNotEmpty) return LatLng(widget.path.last.lat, widget.path.last.lng);
    return _me ?? kDefaultMapCenter;
  }

  /// What the map frames: the journey ahead (the driver, the places still to
  /// visit and the route between them) while there is one, otherwise everything.
  Iterable<LatLng> get _framePoints {
    final route = _route;
    if (route != null && _me != null && widget.routeStops.isNotEmpty) {
      return [
        _me!,
        for (final stop in widget.routeStops) LatLng(stop.latitude, stop.longitude),
        ...route.points,
      ];
    }

    return [
      for (final place in widget.places) LatLng(place.latitude, place.longitude),
      for (final p in thinPath(widget.path, max: 100)) LatLng(p.lat, p.lng),
      if (_me != null) _me!,
    ];
  }

  /// Frames everything on the map. Failing to (the map not laid out yet, a
  /// platform hiccup) is harmless — the map just stays where it is.
  Future<void> _fit() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      final points = _framePoints.toList();
      final bounds = boundsOf(points);
      if (bounds != null) {
        // The small inline map can't afford the padding of the full screen one.
        await controller.animateCamera(CameraUpdate.newLatLngBounds(withTopRoom(bounds), widget.height == null ? 56 : 36));
      } else if (points.isNotEmpty) {
        await controller.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      }
    } catch (_) {}
  }

  /// Starts following the driver's position. Never prompts for permission
  /// unless [askPermission] (the "my location" button): opening a hire
  /// shouldn't throw a permission dialog at the driver. Returns whether the
  /// position is being followed.
  Future<bool> _watchMe({required bool askPermission}) async {
    if (_meSub != null) return true;

    final stream = widget.locationOverride ?? await _gpsStream(askPermission: askPermission);
    if (stream == null) return false;
    if (!mounted || _meSub != null) return _meSub != null;

    _meSub = stream.listen(_onMe, onError: (_) {});
    return true;
  }

  Future<Stream<LatLng>?> _gpsStream({required bool askPermission}) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && askPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      return Geolocator.getPositionStream(
        // Coarse and infrequent on purpose: this only moves a dot on a preview.
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, distanceFilter: 25),
      ).map((position) => LatLng(position.latitude, position.longitude));
    } catch (_) {
      return null;
    }
  }

  void _onMe(LatLng me) {
    if (!mounted) return;

    final first = _me == null;
    _lastKnownMe = me;
    _lastKnownMeAt = DateTime.now();
    setState(() => _me = me);
    if (first) unawaited(_fit()); // include the driver in the opening frame
    unawaited(_refreshRoute());
  }

  /// Draws the route ahead from the driver's position: a straight line at once
  /// so the direction is visible immediately, then the road route once it has
  /// been planned. Planned again only when the driver has moved well away, and
  /// not more often than [_replanEvery].
  Future<void> _refreshRoute() async {
    if (!mounted) return;

    if (widget.routeStops.isEmpty) {
      if (_route != null) setState(() => _route = null);
      return;
    }

    final me = _me;
    if (me == null || _planning) return;

    final origin = _routeOrigin;
    if (_route != null && origin != null) {
      final moved = distanceMeters(origin.latitude, origin.longitude, me.latitude, me.longitude);
      final stale = _routeAt == null || DateTime.now().difference(_routeAt!) >= _replanEvery;
      if (moved < _replanMeters || !stale) return;
    }

    final firstDraw = _route == null;
    final stops = widget.routeStops;
    setState(() {
      _route = straightRoute(me, stops);
      _routeOrigin = me;
      _routeAt = DateTime.now();
    });
    if (firstDraw) unawaited(_fit());

    final plan = widget.planRoute;
    if (plan == null) return;

    _planning = true;
    setState(() {});
    try {
      final planned = await plan(me);

      // The hire moved on (or the map went away) while this was being planned.
      if (!mounted || planned == null || !listEquals(stops, widget.routeStops)) return;

      setState(() => _route = planned);
      if (firstDraw) unawaited(_fit()); // the road bends away from the straight line
    } catch (_) {
      // keep the straight line
    } finally {
      if (mounted) setState(() => _planning = false);
    }
  }

  Future<void> _goToMe() async {
    if (!await _watchMe(askPermission: true)) return;

    // The stream only speaks when the phone moves — ask once for where it is now.
    if (_me == null && widget.locationOverride == null) {
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
        );
        _onMe(LatLng(position.latitude, position.longitude));
      } catch (_) {}
    }

    final me = _me;
    if (me == null) return;
    try {
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(me, 15));
    } catch (_) {}
  }

  /// What the route chip says: where to, and how far — or that it's still being
  /// planned / only a straight line.
  String _routeText() {
    final route = _route!;
    final destination = widget.routeStops.last.name;

    if (!route.approximate) {
      final summary = route.summary;
      return summary == null ? 'To $destination' : 'To $destination · $summary';
    }
    return _planning ? 'To $destination · planning route…' : 'To $destination · straight line';
  }

  @override
  Widget build(BuildContext context) {
    final map = Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _initialTarget, zoom: _hasData ? 12 : 7),
          markers: hireMarkers(widget.places, pins: _pins, me: _me, meIcon: _meIcon),
          polylines: {...hireRouteLines(_route), ...hirePathLines(widget.path)},
          myLocationButtonEnabled: false,
          zoomControlsEnabled: widget.interactive,
          mapToolbarEnabled: false,
          compassEnabled: false,
          gestureRecognizers: widget.interactive
              ? const <Factory<OneSequenceGestureRecognizer>>{Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)}
              : const <Factory<OneSequenceGestureRecognizer>>{},
          onMapCreated: (controller) {
            _controller = controller;
            // Give the map a moment to lay out before framing it.
            Future<void>.delayed(const Duration(milliseconds: 350), _fit);
          },
        ),
        // Top-right, clear of Google's own controls along the bottom edge.
        Positioned(
          right: 8,
          top: 8,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MapButton(icon: Icons.zoom_out_map, tooltip: 'Show everything', onTap: _fit),
              const SizedBox(height: 8),
              _MapButton(icon: Icons.my_location, tooltip: 'My location', onTap: _goToMe),
            ],
          ),
        ),
        if (!_hasData && _route == null)
          Positioned(
            left: 8,
            right: 64,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "This hire's locations have no coordinates saved yet, so they can't be plotted.",
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.3),
              ),
            ),
          ),
        if (_route != null && widget.routeStops.isNotEmpty)
          Positioned(
            left: 8,
            right: 64,
            top: 8,
            child: _RouteChip(text: _routeText()),
          ),
      ],
    );

    return widget.height == null ? map : SizedBox(height: widget.height, child: map);
  }
}

class _RouteChip extends StatelessWidget {
  final String text;

  const _RouteChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alt_route, size: 15, color: kRouteColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 2,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 20, color: AppColors.neonDeep),
          ),
        ),
      ),
    );
  }
}

/// What each marker colour means — only the kinds this hire actually has.
class HireMapLegend extends StatelessWidget {
  final List<HireMapPoint> places;
  final bool hasPath;

  /// A route ahead is being drawn.
  final bool hasRoute;

  const HireMapLegend({super.key, required this.places, required this.hasPath, this.hasRoute = false});

  @override
  Widget build(BuildContext context) {
    final roles = {for (final place in places) place.role};
    final items = <Widget>[
      for (final role in MapRole.values)
        if (roles.contains(role))
          _LegendDot(
            color: mapRoleColor(role),
            label: switch (role) {
              MapRole.pickup => 'Pickup',
              MapRole.end => 'End',
              MapRole.stop => 'Stops',
              MapRole.single => 'Location',
            },
          ),
      const _LegendDot(color: Color(0xFF2563EB), label: 'You'),
      if (hasRoute) const _LegendDot(color: kRouteColor, label: 'Route', line: true),
      if (hasPath) const _LegendDot(color: Color(0xFF0D9488), label: 'Driven path', line: true),
    ];

    return Wrap(spacing: 14, runSpacing: 6, children: items);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final bool line;

  const _LegendDot({required this.color, required this.label, this.line = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: line ? 16 : 10,
          height: line ? 4 : 10,
          decoration: BoxDecoration(
            color: color,
            shape: line ? BoxShape.rectangle : BoxShape.circle,
            borderRadius: line ? BorderRadius.circular(2) : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
      ],
    );
  }
}

/// The hire page's map card: a preview with a legend and a button that opens
/// the map full screen.
class HireMapCard extends StatelessWidget {
  final int hireId;
  final List<HireMapPoint> places;
  final List<TrackPoint> path;

  /// The places still ahead of the driver, and how to plan the road to them —
  /// see [HireMapView].
  final List<HireMapPoint> routeStops;
  final Future<PlannedRoute?> Function(LatLng origin)? planRoute;

  const HireMapCard({
    super.key,
    required this.hireId,
    required this.places,
    required this.path,
    this.routeStops = const [],
    this.planRoute,
  });

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
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Map',
                  style: TextStyle(color: AppColors.neon, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => HireMapScreen(
                      hireId: hireId,
                      places: places,
                      path: path,
                      routeStops: routeStops,
                      planRoute: planRoute,
                    ),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen, size: 18, color: AppColors.neonDeep),
                      SizedBox(width: 4),
                      Text('Full screen', style: TextStyle(color: AppColors.neonDeep, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: HireMapView(places: places, path: path, height: 240, routeStops: routeStops, planRoute: planRoute),
          ),
          const SizedBox(height: 10),
          HireMapLegend(places: places, hasPath: path.length > 1, hasRoute: routeStops.isNotEmpty),
        ],
      ),
    );
  }
}

/// The map on its own screen, where it can be panned and zoomed freely.
class HireMapScreen extends StatelessWidget {
  final int hireId;
  final List<HireMapPoint> places;
  final List<TrackPoint> path;
  final List<HireMapPoint> routeStops;
  final Future<PlannedRoute?> Function(LatLng origin)? planRoute;

  const HireMapScreen({
    super.key,
    required this.hireId,
    required this.places,
    required this.path,
    this.routeStops = const [],
    this.planRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hire #$hireId · Map')),
      body: Column(
        children: [
          Expanded(
            child: HireMapView(places: places, path: path, interactive: true, routeStops: routeStops, planRoute: planRoute),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: HireMapLegend(places: places, hasPath: path.length > 1, hasRoute: routeStops.isNotEmpty),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
