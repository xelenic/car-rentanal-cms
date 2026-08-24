class Hire {
  final int id;
  final String tourType;
  final String tourTypeLabel;
  final String? fromLocation;
  final String? toLocation;
  final List<String> stayLocations;
  final String? package;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? vehicle;
  final double hireFullValue;
  final String paymentType;
  final String paymentTypeLabel;
  final String? description;
  final DateTime? createdAt;
  final String status;
  final String statusLabel;
  final bool isTracking;
  final DateTime? trackingStartedAt;
  final DateTime? trackingStoppedAt;
  final double totalDistanceKm;

  Hire({
    required this.id,
    required this.tourType,
    required this.tourTypeLabel,
    this.fromLocation,
    this.toLocation,
    this.stayLocations = const [],
    this.package,
    this.startTime,
    this.endTime,
    this.vehicle,
    required this.hireFullValue,
    required this.paymentType,
    required this.paymentTypeLabel,
    this.description,
    this.createdAt,
    this.status = 'pending',
    this.statusLabel = 'Pending',
    this.isTracking = false,
    this.trackingStartedAt,
    this.trackingStoppedAt,
    this.totalDistanceKm = 0,
  });

  factory Hire.fromJson(Map<String, dynamic> json) {
    return Hire(
      id: json['id'] as int,
      tourType: json['tour_type'] as String,
      tourTypeLabel: json['tour_type_label'] as String,
      fromLocation: json['from_location'] as String?,
      toLocation: json['to_location'] as String?,
      stayLocations: (json['stay_locations'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      package: json['package'] as String?,
      startTime: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'] as String)
          : null,
      endTime: json['end_time'] != null
          ? DateTime.tryParse(json['end_time'] as String)
          : null,
      vehicle: json['vehicle'] as String?,
      hireFullValue: (json['hire_full_value'] as num).toDouble(),
      paymentType: json['payment_type'] as String,
      paymentTypeLabel: json['payment_type_label'] as String,
      description: json['description'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
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

  Hire copyWith({
    String? status,
    String? statusLabel,
    bool? isTracking,
    DateTime? trackingStartedAt,
    DateTime? trackingStoppedAt,
    double? totalDistanceKm,
  }) {
    return Hire(
      id: id,
      tourType: tourType,
      tourTypeLabel: tourTypeLabel,
      fromLocation: fromLocation,
      toLocation: toLocation,
      stayLocations: stayLocations,
      package: package,
      startTime: startTime,
      endTime: endTime,
      vehicle: vehicle,
      hireFullValue: hireFullValue,
      paymentType: paymentType,
      paymentTypeLabel: paymentTypeLabel,
      description: description,
      createdAt: createdAt,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      isTracking: isTracking ?? this.isTracking,
      trackingStartedAt: trackingStartedAt ?? this.trackingStartedAt,
      trackingStoppedAt: trackingStoppedAt ?? this.trackingStoppedAt,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
    );
  }

  bool get isCompleted => status == 'completed';

  /// A hire scheduled ahead of time (see the admin panel's "Schedule"
  /// field) whose date hasn't arrived yet — tracking can't be started or
  /// completed until then (enforced server-side too, see
  /// HireTrackingController::assertScheduleReached()).
  bool get isScheduledInFuture => startTime != null && startTime!.isAfter(DateTime.now());

  /// A short, human-readable summary of the route/tour for this hire,
  /// tailored to whichever tour type it is.
  String get routeSummary {
    switch (tourType) {
      case 'package':
        return package ?? 'Package tour';
      case 'multi_day':
        return stayLocations.isNotEmpty
            ? stayLocations.join(' → ')
            : 'Multi day tour';
      default:
        final from = fromLocation ?? '—';
        final to = toLocation ?? '—';
        return '$from → $to';
    }
  }
}
