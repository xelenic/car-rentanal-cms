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
    this.canViewMyExpenses = false,
    this.canCreateMyExpenses = false,
    this.canUpdateMyExpenses = false,
    this.canDeleteMyExpenses = false,
  });

  final int id;
  final String name;
  final String email;
  final bool canCreateHires;
  final bool canUpdateHires;
  final bool canDeleteHires;
  final bool canViewVehicles;
  final bool canCreateVehicles;
  final bool canViewMyExpenses;
  final bool canCreateMyExpenses;
  final bool canUpdateMyExpenses;
  final bool canDeleteMyExpenses;

  /// Whether the categories screen has anything to offer this user.
  bool get canManageExpenseCategories => canCreateMyExpenses || canUpdateMyExpenses || canDeleteMyExpenses;

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
      canViewMyExpenses: json['can_view_my_expenses'] as bool? ?? false,
      canCreateMyExpenses: json['can_create_my_expenses'] as bool? ?? false,
      canUpdateMyExpenses: json['can_update_my_expenses'] as bool? ?? false,
      canDeleteMyExpenses: json['can_delete_my_expenses'] as bool? ?? false,
    );
  }
}
