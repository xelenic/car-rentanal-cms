import 'hire_tab.dart';

double _number(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

int _int(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;

/// How many hires a vehicle has under each tab — mirrors the "counts" block
/// of Api\Admin\VehicleResource.
class HireCounts {
  const HireCounts({
    this.all = 0,
    this.today = 0,
    this.scheduled = 0,
    this.completed = 0,
    this.cancelled = 0,
    this.running = 0,
  });

  final int all;
  final int today;
  final int scheduled;
  final int completed;
  final int cancelled;

  /// Hires the driver has started and not finished — part of "today".
  final int running;

  int of(HireTab tab) => switch (tab) {
        HireTab.all => all,
        HireTab.today => today,
        HireTab.scheduled => scheduled,
        HireTab.completed => completed,
        HireTab.cancelled => cancelled,
      };

  factory HireCounts.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const HireCounts();
    return HireCounts(
      all: _int(json['all']),
      today: _int(json['today']),
      scheduled: _int(json['scheduled']),
      completed: _int(json['completed']),
      cancelled: _int(json['cancelled']),
      running: _int(json['running']),
    );
  }
}

/// A vehicle's hire numbers. Money is over hires that earn — a cancelled hire
/// earned nothing, so it isn't in [hireCount] or the totals (see
/// [HireCounts.cancelled]).
class VehicleStats {
  const VehicleStats({
    this.hireCount = 0,
    this.hireFullValueTotal = 0,
    this.ourHireValueTotal = 0,
    this.commissionTotal = 0,
    this.monthHireCount = 0,
    this.monthHireFullValueTotal = 0,
    this.monthCommissionTotal = 0,
    this.counts = const HireCounts(),
  });

  final int hireCount;
  final double hireFullValueTotal;
  final double ourHireValueTotal;
  final double commissionTotal;
  final int monthHireCount;
  final double monthHireFullValueTotal;
  final double monthCommissionTotal;
  final HireCounts counts;

  factory VehicleStats.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const VehicleStats();
    final month = json['month'] as Map<String, dynamic>? ?? const {};
    return VehicleStats(
      hireCount: _int(json['hire_count']),
      hireFullValueTotal: _number(json['hire_full_value_total']),
      ourHireValueTotal: _number(json['our_hire_value_total']),
      commissionTotal: _number(json['commission_total']),
      monthHireCount: _int(month['hire_count']),
      monthHireFullValueTotal: _number(month['hire_full_value_total']),
      monthCommissionTotal: _number(month['commission_total']),
      counts: HireCounts.fromJson(json['counts'] as Map<String, dynamic>?),
    );
  }
}

/// A vehicle card — mirrors Api\Admin\VehicleResource.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.model,
    required this.condition,
    required this.seats,
    required this.pax,
    this.description,
    this.stats = const VehicleStats(),
  });

  final int id;
  final String model;
  final String condition;
  final int seats;
  final int pax;
  final String? description;
  final VehicleStats stats;

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    final description = json['description'] as String?;
    return Vehicle(
      id: json['id'] as int,
      model: json['model'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      seats: _int(json['seats']),
      pax: _int(json['pax']),
      description: description != null && description.trim().isNotEmpty ? description : null,
      stats: VehicleStats.fromJson(json['stats'] as Map<String, dynamic>?),
    );
  }
}

/// A page of the fleet from GET /admin/vehicles.
class VehiclePage {
  const VehiclePage({
    required this.vehicles,
    required this.currentPage,
    required this.lastPage,
  });

  final List<Vehicle> vehicles;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory VehiclePage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>?;
    return VehiclePage(
      vehicles: (json['data'] as List<dynamic>? ?? [])
          .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentPage: (meta?['current_page'] as int?) ?? 1,
      lastPage: (meta?['last_page'] as int?) ?? 1,
    );
  }
}

/// The values the Add Vehicle form sends. Conditions mirror Vehicle::CONDITIONS
/// on the server, which rejects anything else.
const vehicleConditions = ['New', 'Excellent', 'Good', 'Fair', 'Poor'];
