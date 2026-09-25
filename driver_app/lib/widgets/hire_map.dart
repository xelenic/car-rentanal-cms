import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/hire_map_point.dart';
import '../models/map_role.dart';
import '../models/tracking_status.dart';
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
      color: AppColors.neonDeep,
      width: 5,
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

  const HireMapView({
    super.key,
    required this.places,
    this.path = const [],
    this.height,
    this.interactive = false,
    this.locationOverride,
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

  bool get _hasData => widget.places.isNotEmpty || widget.path.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _me = _recentKnownMe();
    _loadPins();
    _loadMeIcon();
    _watchMe(askPermission: false);
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
  }

  @override
  void dispose() {
    _meSub?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  LatLng get _initialTarget {
    if (widget.places.isNotEmpty) return LatLng(widget.places.first.latitude, widget.places.first.longitude);
    if (widget.path.isNotEmpty) return LatLng(widget.path.last.lat, widget.path.last.lng);
    return _me ?? kDefaultMapCenter;
  }

  Iterable<LatLng> get _framePoints => [
        for (final place in widget.places) LatLng(place.latitude, place.longitude),
        for (final p in thinPath(widget.path, max: 100)) LatLng(p.lat, p.lng),
        if (_me != null) _me!,
      ];

  /// Frames everything on the map. Failing to (the map not laid out yet, a
  /// platform hiccup) is harmless — the map just stays where it is.
  Future<void> _fit() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      final points = _framePoints.toList();
      final bounds = boundsOf(points);
      if (bounds != null) {
        await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 56));
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

  @override
  Widget build(BuildContext context) {
    final map = Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _initialTarget, zoom: _hasData ? 12 : 7),
          markers: hireMarkers(widget.places, pins: _pins, me: _me, meIcon: _meIcon),
          polylines: hirePathLines(widget.path),
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
        if (!_hasData)
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
      ],
    );

    return widget.height == null ? map : SizedBox(height: widget.height, child: map);
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

  const HireMapLegend({super.key, required this.places, required this.hasPath});

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
      if (hasPath) const _LegendDot(color: AppColors.neonDeep, label: 'Driven path', line: true),
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

  const HireMapCard({super.key, required this.hireId, required this.places, required this.path});

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
                  MaterialPageRoute(builder: (_) => HireMapScreen(hireId: hireId, places: places, path: path)),
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
            child: HireMapView(places: places, path: path, height: 240),
          ),
          const SizedBox(height: 10),
          HireMapLegend(places: places, hasPath: path.length > 1),
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

  const HireMapScreen({super.key, required this.hireId, required this.places, required this.path});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Hire #$hireId · Map')),
      body: Column(
        children: [
          Expanded(child: HireMapView(places: places, path: path, interactive: true)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: HireMapLegend(places: places, hasPath: path.length > 1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
