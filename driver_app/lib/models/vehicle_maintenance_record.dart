/// A vehicle Service / Repair / Parts entry logged by the driver. Separate
/// from [HireExpense]: it's about the vehicle, not a specific hire, and is
/// never counted as a deductible expense or deducted from salary.
class VehicleMaintenanceRecord {
  static const typeLabels = <String, String>{
    'service': 'Vehicle Service',
    'repair': 'Vehicle Repair',
    'parts': 'Vehicle Parts',
  };

  final int id;
  final int vehicleId;
  final String? vehicleModel;
  final String type;
  final String typeLabel;
  final int? mileage;
  final double cost;
  final String? description;
  final String? billUrl;
  final DateTime? createdAt;

  VehicleMaintenanceRecord({
    required this.id,
    required this.vehicleId,
    this.vehicleModel,
    required this.type,
    required this.typeLabel,
    this.mileage,
    required this.cost,
    this.description,
    this.billUrl,
    this.createdAt,
  });

  factory VehicleMaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return VehicleMaintenanceRecord(
      id: json['id'] as int,
      vehicleId: json['vehicle_id'] as int,
      vehicleModel: json['vehicle_model'] as String?,
      type: json['type'] as String,
      typeLabel: json['type_label'] as String,
      mileage: json['mileage'] as int?,
      cost: (json['cost'] as num).toDouble(),
      description: json['description'] as String?,
      billUrl: json['bill_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}
