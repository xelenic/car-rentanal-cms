import 'dart:math' as math;

/// Metres between two latitude/longitude points (haversine) — plain Dart so
/// the arrival check works, and is testable, without any location plugin.
double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;

  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);

  return 2 * earthRadius * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Decides when the driver counts as having "arrived" at the pickup location.
///
/// GPS wobbles and a saved location is often a rough town-centre point, so
/// arrival is generous ([enterRadiusMeters]) and, once reached, only ends when
/// the phone is clearly gone again ([exitRadiusMeters], further out) — without
/// that gap the highlight would flicker on and off at the edge of the circle.
class ArrivalDetector {
  static const double defaultEnterRadiusMeters = 250;
  static const double defaultExitRadiusMeters = 350;

  final double enterRadiusMeters;
  final double exitRadiusMeters;

  ArrivalDetector({
    this.enterRadiusMeters = defaultEnterRadiusMeters,
    this.exitRadiusMeters = defaultExitRadiusMeters,
  }) : assert(exitRadiusMeters >= enterRadiusMeters);

  bool _arrived = false;

  bool get arrived => _arrived;

  /// Feeds in the latest distance to the pickup location. Returns true when
  /// this reading changed [arrived].
  bool update(double distanceMeters) {
    final next = _arrived ? distanceMeters <= exitRadiusMeters : distanceMeters <= enterRadiusMeters;
    final changed = next != _arrived;
    _arrived = next;
    return changed;
  }

  void reset() => _arrived = false;
}
