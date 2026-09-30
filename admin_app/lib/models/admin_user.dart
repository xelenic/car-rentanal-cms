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
    this.canUpdateVehicles = false,
    this.canDeleteVehicles = false,
    this.canViewDrivers = false,
    this.canCreateDrivers = false,
    this.canUpdateDrivers = false,
    this.canDeleteDrivers = false,
    this.canViewCustomers = false,
    this.canCreateCustomers = false,
    this.canUpdateCustomers = false,
    this.canDeleteCustomers = false,
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
  final bool canUpdateVehicles;
  final bool canDeleteVehicles;
  final bool canViewDrivers;
  final bool canCreateDrivers;
  final bool canUpdateDrivers;
  final bool canDeleteDrivers;
  final bool canViewCustomers;
  final bool canCreateCustomers;
  final bool canUpdateCustomers;
  final bool canDeleteCustomers;
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
      canUpdateVehicles: json['can_update_vehicles'] as bool? ?? false,
      canDeleteVehicles: json['can_delete_vehicles'] as bool? ?? false,
      canViewDrivers: json['can_view_drivers'] as bool? ?? false,
      canCreateDrivers: json['can_create_drivers'] as bool? ?? false,
      canUpdateDrivers: json['can_update_drivers'] as bool? ?? false,
      canDeleteDrivers: json['can_delete_drivers'] as bool? ?? false,
      canViewCustomers: json['can_view_customers'] as bool? ?? false,
      canCreateCustomers: json['can_create_customers'] as bool? ?? false,
      canUpdateCustomers: json['can_update_customers'] as bool? ?? false,
      canDeleteCustomers: json['can_delete_customers'] as bool? ?? false,
      canViewMyExpenses: json['can_view_my_expenses'] as bool? ?? false,
      canCreateMyExpenses: json['can_create_my_expenses'] as bool? ?? false,
      canUpdateMyExpenses: json['can_update_my_expenses'] as bool? ?? false,
      canDeleteMyExpenses: json['can_delete_my_expenses'] as bool? ?? false,
    );
  }
}
