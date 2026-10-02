import '../models/hire.dart';
import '../models/hire_stage.dart';
import '../models/map_role.dart';
import '../models/tracking_status.dart';
import 'arrival_detector.dart';

/// Which place on the trip the driver is heading for.
enum ArrivalGoal {
  /// Before the hire is started: the pickup location, where the Start button
  /// lights up.
  pickup,

  /// Once it has started, a stay in between on a day tour or multi day tour —
  /// reaching one just moves the watch on to the next; nothing to tap.
  stop,

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
///  * Started (running, or paused after a Stop): each stay in between, in
///    journey order, then the end location — a day tour or multi day tour
///    gets its own arrival moment at every stop instead of only the final
///    one. A stop already reached is told apart from one still ahead two
///    ways: [path] (the trip recorded so far — see [pathHasVisitedAndLeft];
///    covers the app having been closed while it happened) and [alsoPassed]
///    (stops the screen itself watched the driver arrive at and then leave
///    this session — quicker than waiting for the next recorded point). A
///    hire with a single place has no separate end, so nothing lights up —
///    the driver would already be standing at it.
ArrivalTarget? arrivalTargetFor(
  Hire hire, {
  required HireStage stage,
  List<TrackPoint> path = const [],
  Set<ArrivalTarget> alsoPassed = const {},
}) {
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

  for (final place in hire.mapPoints) {
    if (place.role != MapRole.stop && place.role != MapRole.end) continue;

    final target = ArrivalTarget(
      goal: place.role == MapRole.end ? ArrivalGoal.end : ArrivalGoal.stop,
      name: place.name,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    // The end is always the target once every stop before it is done —
    // arriving there doesn't advance anywhere, it finishes the trip.
    if (target.goal == ArrivalGoal.end || (!alsoPassed.contains(target) && !pathHasVisitedAndLeft(path, target))) {
      return target;
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

/// Whether the recorded path shows a stop was actually reached and then left
/// — unlike [pathHasLeft], a path that never came near [target] in the first
/// place doesn't count: a day tour's second stop is miles from the first the
/// whole time the driver is still on the way to it, and that must keep
/// watching the first stop, not skip straight past it.
bool pathHasVisitedAndLeft(
  List<TrackPoint> path,
  ArrivalTarget target, {
  double enterMeters = ArrivalDetector.defaultEnterRadiusMeters,
  double exitMeters = ArrivalDetector.defaultExitRadiusMeters,
}) {
  var visited = false;
  for (final point in path) {
    final distance = distanceMeters(point.lat, point.lng, target.latitude, target.longitude);
    if (!visited) {
      if (distance <= enterMeters) visited = true;
    } else if (distance > exitMeters) {
      return true;
    }
  }
  return false;
}
