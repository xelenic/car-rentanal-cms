/// A minimal vehicle reference — just enough for the driver app's vehicle
/// picker (e.g. when logging a Vehicle Service / Repair / Parts record).
class Vehicle {
  final int id;
  final String model;

  Vehicle({required this.id, required this.model});

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    return Vehicle(
      id: json['id'] as int,
      model: json['model'] as String,
    );
  }
}
