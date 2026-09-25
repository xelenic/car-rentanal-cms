/// The logged-in admin/staff user — mirrors Api\Admin\AuthController's
/// userPayload() shape.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.canCreateHires,
    this.canUpdateHires = false,
    this.canDeleteHires = false,
    this.canViewVehicles = false,
    this.canCreateVehicles = false,
  });

  final int id;
  final String name;
  final String email;
  final bool canCreateHires;
  final bool canUpdateHires;
  final bool canDeleteHires;
  final bool canViewVehicles;
  final bool canCreateVehicles;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      canCreateHires: json['can_create_hires'] as bool? ?? false,
      canUpdateHires: json['can_update_hires'] as bool? ?? false,
      canDeleteHires: json['can_delete_hires'] as bool? ?? false,
      canViewVehicles: json['can_view_vehicles'] as bool? ?? false,
      canCreateVehicles: json['can_create_vehicles'] as bool? ?? false,
    );
  }
}
