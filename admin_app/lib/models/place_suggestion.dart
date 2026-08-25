/// A single Google Places suggestion, from Api\Admin\PlaceController's
/// autocomplete proxy.
class PlaceSuggestion {
  const PlaceSuggestion({required this.placeId, required this.description});

  final String placeId;
  final String description;

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
    );
  }
}

/// A resolved place's coordinates, from the details proxy — fetched only
/// after the user actually picks a suggestion (matches the web admin
/// panel's Autocomplete widget, which also defers the extra API call
/// until selection).
class PlaceDetails {
  const PlaceDetails({this.name, this.lat, this.lng});

  final String? name;
  final double? lat;
  final double? lng;

  bool get hasCoordinates => lat != null && lng != null;

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      name: json['name'] as String?,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}
