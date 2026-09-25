import 'map_role.dart';

/// One place on a hire's trip with coordinates — what the hire page's map
/// draws as a marker. Comes from the API's `map_locations`.
class HireMapPoint {
  final MapRole role;
  final String name;
  final double latitude;
  final double longitude;

  const HireMapPoint({
    required this.role,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  /// What the place is for this hire, as shown on its marker.
  String get label {
    switch (role) {
      case MapRole.pickup:
        return 'Pickup location';
      case MapRole.end:
        return 'End location';
      case MapRole.stop:
        return 'Stop';
      case MapRole.single:
        return 'Location';
    }
  }

  /// Null for anything that isn't a well-formed place (the server may add
  /// fields or roles later — an unknown one must not break the hire screen).
  static HireMapPoint? tryParse(Object? json) {
    if (json is! Map) return null;

    final lat = json['latitude'];
    final lng = json['longitude'];
    final name = json['name'];
    if (lat is! num || lng is! num || name is! String) return null;

    final role = switch (json['role']) {
      'pickup' => MapRole.pickup,
      'end' => MapRole.end,
      'stop' => MapRole.stop,
      'single' => MapRole.single,
      _ => null,
    };
    if (role == null) return null;

    return HireMapPoint(role: role, name: name, latitude: lat.toDouble(), longitude: lng.toDouble());
  }

  @override
  bool operator ==(Object other) =>
      other is HireMapPoint &&
      other.role == role &&
      other.name == name &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(role, name, latitude, longitude);
}
