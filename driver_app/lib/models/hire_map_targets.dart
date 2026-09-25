import 'hire.dart';
import 'hire_stage.dart';
import 'map_role.dart';

export 'map_role.dart';

/// One place on a hire the driver can open in Google Maps.
class MapTarget {
  final MapRole role;

  /// What the place is for this hire: "Pickup location", "End location",
  /// "Stop 2" …
  final String label;

  /// The place name — Google Maps resolves it (the saved coordinates aren't
  /// used for this: a name always lands on the right town).
  final String place;

  const MapTarget({required this.role, required this.label, required this.place});

  @override
  bool operator ==(Object other) =>
      other is MapTarget && other.role == role && other.label == label && other.place == place;

  @override
  int get hashCode => Object.hash(role, label, place);
}

bool _named(String? value) => value != null && value.trim().isNotEmpty;

/// Every place on the hire the driver may need to navigate to, in journey
/// order, each labelled by its part in the trip — so the pickup and the end
/// location are separate buttons instead of one that opens whichever comes
/// first.
///
///  * drop-and-pickup / day tours: the "from" place is the pickup location,
///    the "to" place the end location;
///  * multi day tours: the first stay is the pickup location, the last the end
///    location and anything between "Stop N";
///  * package tours: the package's own location.
List<MapTarget> mapTargetsOf(Hire hire) {
  final targets = <MapTarget>[];

  void addStays() {
    final stays = hire.stayLocations.where(_named).map((s) => s.trim()).toList();
    if (stays.length == 1) {
      targets.add(MapTarget(role: MapRole.single, label: 'Location', place: stays.first));
      return;
    }
    for (var i = 0; i < stays.length; i++) {
      final first = i == 0;
      final last = i == stays.length - 1;
      targets.add(MapTarget(
        role: first ? MapRole.pickup : (last ? MapRole.end : MapRole.stop),
        label: first ? 'Pickup location' : (last ? 'End location' : 'Stop ${i + 1}'),
        place: stays[i],
      ));
    }
  }

  switch (hire.tourType) {
    case 'multi_day':
      addStays();
    case 'package':
      if (_named(hire.package)) {
        targets.add(MapTarget(role: MapRole.single, label: 'Package location', place: hire.package!.trim()));
      }
    default:
      if (_named(hire.fromLocation)) {
        targets.add(MapTarget(role: MapRole.pickup, label: 'Pickup location', place: hire.fromLocation!.trim()));
      }
      if (_named(hire.toLocation)) {
        targets.add(MapTarget(role: MapRole.end, label: 'End location', place: hire.toLocation!.trim()));
      }
  }

  // A hire of any type that only has stays, or only a package, still gets a button.
  if (targets.isEmpty) addStays();
  if (targets.isEmpty && _named(hire.package)) {
    targets.add(MapTarget(role: MapRole.single, label: 'Package location', place: hire.package!.trim()));
  }

  return targets;
}

/// The place the driver should be heading for right now: the pickup location
/// until the hire has been started, the end location after. A hire with a
/// single place (a package, a one-stay tour) points at it the whole way; a
/// finished hire has nowhere left to go.
MapTarget? mapTargetFor(Hire hire, HireStage stage) {
  if (stage == HireStage.completed) return null;

  final beforeStart = stage == HireStage.pickup || (stage == HireStage.start && hire.trackingStartedAt == null);
  final wanted = beforeStart ? MapRole.pickup : MapRole.end;
  final targets = mapTargetsOf(hire);

  for (final role in [wanted, MapRole.single]) {
    for (final target in targets) {
      if (target.role == role) return target;
    }
  }
  return null;
}

/// A multi-stop Google Maps route from the driver's current location:
/// Your location → [waypoints] → [destination].
///
/// Opening it shows the whole trip at once — to the pickup point *and on to
/// the drop-off* — instead of a route to a single place.
class MapRoute {
  /// Google's Maps URLs accept at most this many intermediate stops.
  static const int maxWaypoints = 9;

  final List<String> waypoints;
  final String destination;

  const MapRoute({required this.waypoints, required this.destination});

  /// Every place after the driver's own location, in order.
  List<String> get places => [...waypoints, destination];

  /// "You → Colombo Fort → Ella"
  String get summary => ['You', ...places].join(' → ');

  /// The directions link. There's deliberately no `origin`: Google Maps then
  /// starts from wherever the driver is when they open it.
  Uri get url {
    String encode(String place) => Uri.encodeComponent(place);

    return Uri.parse('https://www.google.com/maps/dir/?${[
      'api=1',
      'destination=${encode(destination)}',
      if (waypoints.isNotEmpty) 'waypoints=${waypoints.map(encode).join('%7C')}',
      'travelmode=driving',
    ].join('&')}');
  }
}

/// The route to open for this hire at this stage:
///
///  * before the hire starts — Your location → pickup location → end location
///    (through any stops in between on a multi day tour);
///  * once it has started the customer is on board and the pickup is behind
///    the driver, so it's Your location → the rest of the way → end location;
///  * a hire with a single place just goes there;
///  * null for a finished hire, or one with no places to go to.
MapRoute? mapRouteFor(Hire hire, HireStage stage) {
  if (stage == HireStage.completed) return null;

  final beforeStart = stage == HireStage.pickup || (stage == HireStage.start && hire.trackingStartedAt == null);
  final places = mapTargetsOf(hire)
      .where((target) => beforeStart || target.role != MapRole.pickup)
      .map((target) => target.place)
      .toList();
  if (places.isEmpty) return null;

  return MapRoute(
    waypoints: places.sublist(0, places.length - 1).take(MapRoute.maxWaypoints).toList(),
    destination: places.last,
  );
}
