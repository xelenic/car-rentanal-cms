class TrackingStatus {
  final String status;
  final String statusLabel;
  final bool isTracking;
  final DateTime? trackingStartedAt;
  final DateTime? trackingStoppedAt;
  final double totalDistanceKm;

  TrackingStatus({
    required this.status,
    required this.statusLabel,
    required this.isTracking,
    this.trackingStartedAt,
    this.trackingStoppedAt,
    required this.totalDistanceKm,
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
      totalDistanceKm: (json['total_distance_km'] as num?)?.toDouble() ?? 0,
    );
  }
}
