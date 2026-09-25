/// A single recorded GPS point on a hire's tracked path.
class TrackPoint {
  final double lat;
  final double lng;

  const TrackPoint({required this.lat, required this.lng});

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'lat': lat, 'lng': lng};
}

class TrackingStatus {
  final String status;
  final String statusLabel;
  final bool isTracking;
  final DateTime? trackingStartedAt;
  final DateTime? trackingStoppedAt;
  final DateTime? cancelledAt;
  final double totalDistanceKm;
  final List<TrackPoint> points;

  TrackingStatus({
    required this.status,
    required this.statusLabel,
    required this.isTracking,
    this.trackingStartedAt,
    this.trackingStoppedAt,
    this.cancelledAt,
    required this.totalDistanceKm,
    this.points = const [],
  });

  factory TrackingStatus.fromJson(Map<String, dynamic> json) {
    return TrackingStatus(
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['status_label'] as String? ?? 'Pending',
      isTracking: json['is_tracking'] as bool? ?? false,
      trackingStartedAt: json['tracking_started_at'] != null
          ? DateTime.tryParse(json['tracking_started_at'] as String)
          : null,
      trackingStoppedAt: json['tracking_stopped_at'] != null
          ? DateTime.tryParse(json['tracking_stopped_at'] as String)
          : null,
      cancelledAt: json['cancelled_at'] != null ? DateTime.tryParse(json['cancelled_at'] as String) : null,
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0,
      points: (json['points'] as List<dynamic>? ?? [])
          .map((e) => TrackPoint.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  /// Same shape as the API response — lets the background tracking service
  /// (a separate isolate) pass a status to the UI as plain data.
  Map<String, dynamic> toJson() => {
        'status': status,
        'status_label': statusLabel,
        'is_tracking': isTracking,
        'tracking_started_at': trackingStartedAt?.toIso8601String(),
        'tracking_stopped_at': trackingStoppedAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'total_distance_km': totalDistanceKm,
        'points': points.map((p) => p.toJson()).toList(),
      };
}
