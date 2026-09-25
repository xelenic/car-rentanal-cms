import '../models/hire.dart';
import '../models/hire_stage.dart';
import '../models/map_role.dart';
import '../models/tracking_status.dart';
import 'arrival_detector.dart';

/// Which end of the trip the driver is heading for.
enum ArrivalGoal {
  /// Before the hire is started: the pickup location, where the Start button
  /// lights up.
  pickup,

  /// Once it has started: the end location, where Complete Hire lights up.
  end,
}

/// A place the hire screen watches for the driver's arrival at.
class ArrivalTarget {
  final ArrivalGoal goal;
  final String name;
  final double latitude;
  final double longitude;

  const ArrivalTarget({required this.goal, required this.name, required this.latitude, required this.longitude});

  @override
  bool operator ==(Object other) =>
      other is ArrivalTarget &&
      other.goal == goal &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(goal, name, latitude, longitude);
}

/// Where the driver should be told they have arrived, or null when there is
/// nothing to watch for (no coordinates saved, a finished hire, or a hire that
/// hasn't been picked up yet).
///
///  * Not started: the pickup location — only while the Start button is
///    showing ([HireStage.start]).
///  * Started (running, or paused after a Stop): the end location. A hire with
///    a single place has no separate end, so nothing lights up — the driver
///    would already be standing at it.
ArrivalTarget? arrivalTargetFor(Hire hire, {required HireStage stage}) {
  if (stage.isOver) return null;

  if (hire.trackingStartedAt == null) {
    if (stage != HireStage.start || !hire.hasPickupCoordinates) return null;

    return ArrivalTarget(
      goal: ArrivalGoal.pickup,
      name: hire.pickupLocationName ?? 'the pickup location',
      latitude: hire.pickupLatitude!,
      longitude: hire.pickupLongitude!,
    );
  }

  for (final place in hire.mapPoints.reversed) {
    if (place.role == MapRole.end) {
      return ArrivalTarget(goal: ArrivalGoal.end, name: place.name, latitude: place.latitude, longitude: place.longitude);
    }
  }
  return null;
}

/// Pickup and end this close together are the same place for our purposes: a
/// round trip that finishes where it started.
const double kRoundTripMeters = 500;

/// On a round trip the driver is standing at the "end location" the moment
/// they press Start, so arrival must not count until they have been away from
/// it. Any other hire is fine to highlight straight away.
bool endIsWhereItStarted(Hire hire) {
  (double, double)? pickup, end;
  for (final place in hire.mapPoints) {
    if (place.role == MapRole.pickup) pickup ??= (place.latitude, place.longitude);
    if (place.role == MapRole.end) end = (place.latitude, place.longitude);
  }
  if (pickup == null || end == null) return false;

  return distanceMeters(pickup.$1, pickup.$2, end.$1, end.$2) < kRoundTripMeters;
}

/// Whether the recorded path has ever been clear of [target] — proof the
/// driver left, even if the app was closed while they did (the background
/// service kept recording).
bool pathHasLeft(List<TrackPoint> path, ArrivalTarget target, {double exitMeters = ArrivalDetector.defaultExitRadiusMeters}) {
  for (final point in path) {
    if (distanceMeters(point.lat, point.lng, target.latitude, target.longitude) > exitMeters) return true;
  }
  return false;
}
