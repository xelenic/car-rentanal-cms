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

    return const SizedBox.expand(key: Key('fake-google-map'));
  }
}

FakeGoogleMapsPlatform installFakeGoogleMaps() {
  final fake = FakeGoogleMapsPlatform();
  GoogleMapsFlutterPlatform.instance = fake;
  return fake;
}
