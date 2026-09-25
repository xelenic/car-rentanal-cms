/// A location/customer/driver/vehicle name pair, as embedded in a hire.
class HireCustomer {
  const HireCustomer({required this.id, required this.name, this.phone});

  final int id;
  final String name;
  final String? phone;

  factory HireCustomer.fromJson(Map<String, dynamic> json) {
    return HireCustomer(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String?,
    );
  }
}

class HireDriver {
  const HireDriver({required this.id, required this.name});

  final int id;
  final String name;

  factory HireDriver.fromJson(Map<String, dynamic> json) {
    return HireDriver(id: json['id'] as int, name: json['name'] as String? ?? '');
  }
}

class HireVehicle {
  const HireVehicle({required this.id, required this.model});

  final int id;
  final String model;

  factory HireVehicle.fromJson(Map<String, dynamic> json) {
    return HireVehicle(id: json['id'] as int, model: json['model'] as String? ?? '');
  }
}

/// Mirrors App\Http\Resources\Admin\HireResource's shape exactly.
class Hire {
  const Hire({
    required this.id,
    required this.tourType,
    required this.tourTypeLabel,
    required this.status,
    required this.statusLabel,
    required this.isUpcoming,
    this.startTime,
    this.endTime,
    this.fromLocation,
    this.toLocation,
    required this.stayLocations,
    required this.dayLocations,
    this.package,
    this.packageId,
    required this.hireFullValue,
    required this.ourHireValue,
    required this.commission,
    required this.paymentType,
    required this.paymentTypeLabel,
    required this.paidAmount,
    required this.balanceRemaining,
    required this.paymentStatus,
    this.customer,
    this.driver,
    this.vehicle,
    this.description,
    required this.isTracking,
    required this.totalDistanceKm,
    this.cancelledAt,
    this.cancelReason,
    this.createdAt,
  });

  final int id;
  final String tourType;
  final String tourTypeLabel;
  final String status;
  final String statusLabel;
  final bool isUpcoming;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? fromLocation;
  final String? toLocation;
  final List<String> stayLocations;
  final List<List<String>> dayLocations;
  final String? package;
  final int? packageId;
  final double hireFullValue;
  final double ourHireValue;
  final double commission;
  final String paymentType;
  final String paymentTypeLabel;
  final double paidAmount;
  final double balanceRemaining;
  final String paymentStatus;
  final HireCustomer? customer;
  final HireDriver? driver;
  final HireVehicle? vehicle;
  final String? description;
  final bool isTracking;
  final double totalDistanceKm;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final DateTime? createdAt;

  bool get isCancelled => status == 'cancelled';
  bool get isCredit => paymentType == 'credit';
  bool get isFullyPaid => paymentStatus == 'paid';

  factory Hire.fromJson(Map<String, dynamic> json) {
    return Hire(
      id: json['id'] as int,
      tourType: json['tour_type'] as String? ?? '',
      tourTypeLabel: json['tour_type_label'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['status_label'] as String? ?? '',
      isUpcoming: json['is_upcoming'] as bool? ?? false,
      startTime: _parseClockTime(json['start_time']),
      endTime: _parseClockTime(json['end_time']),
      fromLocation: json['from_location'] as String?,
      toLocation: json['to_location'] as String?,
      stayLocations: (json['stay_locations'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      dayLocations: (json['day_locations'] as List<dynamic>? ?? [])
          .map((day) => (day as List<dynamic>).map((e) => e as String).toList())
          .toList(),
      package: json['package'] as String?,
      packageId: json['package_id'] as int?,
      hireFullValue: _parseDouble(json['hire_full_value']),
      ourHireValue: _parseDouble(json['our_hire_value']),
      commission: _parseDouble(json['commission']),
      paymentType: json['payment_type'] as String? ?? 'cash',
      paymentTypeLabel: json['payment_type_label'] as String? ?? '',
      paidAmount: _parseDouble(json['paid_amount']),
      balanceRemaining: _parseDouble(json['balance_remaining']),
      paymentStatus: json['payment_status'] as String? ?? 'unpaid',
      customer: json['customer'] != null
          ? HireCustomer.fromJson(json['customer'] as Map<String, dynamic>)
          : null,
      driver: json['driver'] != null
          ? HireDriver.fromJson(json['driver'] as Map<String, dynamic>)
          : null,
      vehicle: json['vehicle'] != null
          ? HireVehicle.fromJson(json['vehicle'] as Map<String, dynamic>)
          : null,
      description: json['description'] as String?,
      isTracking: json['is_tracking'] as bool? ?? false,
      totalDistanceKm: _parseDouble(json['total_distance_km']),
      cancelledAt: _parseDate(json['cancelled_at']),
      cancelReason: json['cancel_reason'] as String?,
      createdAt: _parseDate(json['created_at']),
    );
  }

  /// A hire's start/end time is a wall-clock time: the server stores it exactly
  /// as it was typed and labels it UTC ("…+00:00") whatever the zone. Read it
  /// back as that same clock time — converting to the phone's zone would show
  /// a different time than the one entered, and editing a hire would push it
  /// later by the offset every time it was saved.
  static DateTime? _parseClockTime(dynamic value) {
    if (value == null) return null;
    final text = value as String;
    final clock = RegExp(r'^\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}(:\d{2})?').firstMatch(text)?.group(0);
    return DateTime.tryParse(clock ?? text);
  }

  /// A real instant (when something happened) — shown in the phone's zone.
  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value as String)?.toLocal();
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}

/// A page of hires from the paginated /api/admin/hires index endpoint
/// (Laravel's default Resource collection pagination envelope).
class HirePage {
  const HirePage({required this.hires, required this.currentPage, required this.lastPage});

  final List<Hire> hires;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory HirePage.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List<dynamic>? ?? [])
        .map((e) => Hire.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>?;

    return HirePage(
      hires: data,
      currentPage: (meta?['current_page'] as int?) ?? 1,
      lastPage: (meta?['last_page'] as int?) ?? 1,
    );
  }
}
