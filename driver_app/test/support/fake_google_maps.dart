import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformViewCreatedCallback;
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

/// Stands in for the phone's map engine in widget tests: no real map is
/// drawn, but everything the app asked the map to show is recorded so tests
/// can check it.
class FakeGoogleMapsPlatform extends GoogleMapsFlutterPlatform {
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  CameraPosition? initialCamera;
  bool myLocationEnabled = false;

  /// Whether the map claimed touch gestures (the full screen map does; the
  /// inline one lets the page scroll over it).
  bool claimsGestures = false;

  int builds = 0;

  /// Real platform views report themselves created exactly once — but
  /// buildViewWithConfiguration is called again on every rebuild, so this
  /// tracks which map ids have already been reported to avoid doing it twice.
  final Set<int> _created = {};

  /// Every bounds the map was asked to fit to (HireMapView's "show
  /// everything" reframing), oldest first — the platform interface throws
  /// UnimplementedError for animateCamera unless a fake overrides it, and
  /// HireMapView._fit() swallows that silently, so without this a test can't
  /// tell whether the map was actually reframed at all.
  final List<LatLngBounds> fitBounds = [];

  /// The plain lat/lng + zoom the map was moved to, when not fitting bounds
  /// (a single place with nothing to frame).
  final List<LatLng> movedTo = [];

  @override
  Widget buildViewWithConfiguration(
    int creationId,
    PlatformViewCreatedCallback onPlatformViewCreated, {
    required MapWidgetConfiguration widgetConfiguration,
    MapConfiguration mapConfiguration = const MapConfiguration(),
    MapObjects mapObjects = const MapObjects(),
  }) {
    builds++;
    markers = mapObjects.markers;
    polylines = mapObjects.polylines;
    initialCamera = widgetConfiguration.initialCameraPosition;
    myLocationEnabled = mapConfiguration.myLocationEnabled ?? false;
    claimsGestures = widgetConfiguration.gestureRecognizers.isNotEmpty;

    // A real platform view reports itself ready exactly once, asynchronously,
    // after the widget has been laid out — mirrored here (rather than calling
    // back synchronously, or on every rebuild) so onMapCreated behaves the
    // same way in tests as it does for real: not yet available on the very
    // first pump, and never invoked twice for the same map.
    if (_created.add(creationId)) {
      scheduleMicrotask(() => onPlatformViewCreated(creationId));
    }

    return const SizedBox.expand(key: Key('fake-google-map'));
  }

  @override
  Future<void> init(int mapId) async {}

  @override
  void dispose({required int mapId}) {}

  @override
  Future<void> animateCamera(CameraUpdate cameraUpdate, {required int mapId}) async {
    switch (cameraUpdate) {
      case CameraUpdateNewLatLngBounds(:final bounds):
        fitBounds.add(bounds);
      case CameraUpdateNewLatLngZoom(:final latLng):
        movedTo.add(latLng);
      default:
        break;
    }
  }

  // The map controller subscribes to these unconditionally once created
  // (see GoogleMapController._connectStreams) — the base class throws for
  // each unless overridden, so without these no map in a test could ever
  // reach "created" at all.
  @override
  Future<void> updateMapConfiguration(MapConfiguration configuration, {required int mapId}) async {}
  @override
  Future<void> updateMarkers(MarkerUpdates markerUpdates, {required int mapId}) async {}
  @override
  Future<void> updatePolylines(PolylineUpdates polylineUpdates, {required int mapId}) async {}
  @override
  Future<void> updatePolygons(PolygonUpdates polygonUpdates, {required int mapId}) async {}
  @override
  Future<void> updateCircles(CircleUpdates circleUpdates, {required int mapId}) async {}
  @override
  Future<void> updateHeatmaps(HeatmapUpdates heatmapUpdates, {required int mapId}) async {}
  @override
  Future<void> updateTileOverlays({required Set<TileOverlay> newTileOverlays, required int mapId}) async {}
  @override
  Future<void> updateClusterManagers(ClusterManagerUpdates clusterManagerUpdates, {required int mapId}) async {}
  @override
  Future<void> updateGroundOverlays(GroundOverlayUpdates groundOverlayUpdates, {required int mapId}) async {}
  @override
  Stream<MarkerTapEvent> onMarkerTap({required int mapId}) => const Stream.empty();
  @override
  Stream<InfoWindowTapEvent> onInfoWindowTap({required int mapId}) => const Stream.empty();
  @override
  Stream<MarkerDragStartEvent> onMarkerDragStart({required int mapId}) => const Stream.empty();
  @override
  Stream<MarkerDragEvent> onMarkerDrag({required int mapId}) => const Stream.empty();
  @override
  Stream<MarkerDragEndEvent> onMarkerDragEnd({required int mapId}) => const Stream.empty();
  @override
  Stream<PolylineTapEvent> onPolylineTap({required int mapId}) => const Stream.empty();
  @override
  Stream<PolygonTapEvent> onPolygonTap({required int mapId}) => const Stream.empty();
  @override
  Stream<CircleTapEvent> onCircleTap({required int mapId}) => const Stream.empty();
  @override
  Stream<MapTapEvent> onTap({required int mapId}) => const Stream.empty();
  @override
  Stream<MapLongPressEvent> onLongPress({required int mapId}) => const Stream.empty();
  @override
  Stream<ClusterTapEvent> onClusterTap({required int mapId}) => const Stream.empty();
}

FakeGoogleMapsPlatform installFakeGoogleMaps() {
  final fake = FakeGoogleMapsPlatform();
  GoogleMapsFlutterPlatform.instance = fake;
  return fake;
}
