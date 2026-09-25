import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../models/hire_map_point.dart';
import '../models/map_role.dart';

/// The way ahead drawn on a hire's map: from the driver's position through
/// whatever is still to come, to the end location.
class PlannedRoute {
  final List<LatLng> points;

  /// A straight line through the stops, drawn at once while the road route is
  /// being planned (and kept if it can't be) — not a real road route.
  final bool approximate;

  final int? distanceMeters;
  final int? durationSeconds;

  const PlannedRoute({
    required this.points,
    this.approximate = false,
    this.distanceMeters,
    this.durationSeconds,
  });

  /// From the API's `GET /driver/hires/{id}/route`.
  factory PlannedRoute.fromJson(Map<String, dynamic> json) {
    return PlannedRoute(
      points: decodePolyline(json['polyline'] as String),
      distanceMeters: (json['distance_m'] as num?)?.toInt(),
      durationSeconds: (json['duration_s'] as num?)?.toInt(),
    );
  }

  /// "76 km · 1 h 32 min", or null when the route has no figures (a straight line).
  String? get summary {
    if (distanceMeters == null || durationSeconds == null) return null;
    return '${formatRouteDistance(distanceMeters!)} · ${formatRouteDuration(durationSeconds!)}';
  }
}

/// Decodes Google's encoded polyline format
/// (https://developers.google.com/maps/documentation/utilities/polylinealgorithm).
List<LatLng> decodePolyline(String encoded) {
  final points = <LatLng>[];
  var index = 0, lat = 0, lng = 0;

  int nextValue() {
    var result = 0, shift = 0;
    int byte;
    do {
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    // Not `~(result >> 1)`: compiled to JavaScript (the web build) `~` returns an
    // unsigned 32-bit number, which turned every negative step into a jump of
    // billions of degrees.
    return (result & 1) != 0 ? -(result >> 1) - 1 : result >> 1;
  }

  while (index < encoded.length) {
    lat += nextValue();
    lng += nextValue();
    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

String formatRouteDistance(int meters) {
  if (meters < 1000) return '$meters m';

  final km = meters / 1000;
  return km >= 100 ? '${km.round()} km' : '${km.toStringAsFixed(1)} km';
}

String formatRouteDuration(int seconds) {
  final minutes = (seconds / 60).round();
  if (minutes < 1) return '1 min';
  if (minutes < 60) return '$minutes min';

  final hours = minutes ~/ 60, rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}

/// What is still ahead of the driver, in order: before the hire has started
/// that is the pickup, any stops, then the end; once it has started the
/// customer is on board and the pickup is behind, so it is just the rest of the
/// way. A finished hire has nothing ahead.
List<HireMapPoint> routeStopsFor(List<HireMapPoint> places, {required bool started, bool completed = false}) {
  if (completed) return const [];
  if (!started) return places;

  return [for (final place in places) if (place.role != MapRole.pickup) place];
}

/// A straight line from [from] through [stops] — shown immediately, and kept
/// if the road route can't be planned (offline, an older server, Directions
/// not available).
PlannedRoute straightRoute(LatLng from, List<HireMapPoint> stops) {
  return PlannedRoute(
    points: [from, for (final stop in stops) LatLng(stop.latitude, stop.longitude)],
    approximate: true,
  );
}
