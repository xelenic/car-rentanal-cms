/// The logged-in admin/staff user — mirrors Api\Admin\AuthController's
/// userPayload() shape.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.canCreateHires,
  });

  final int id;
  final String name;
  final String email;
  final bool canCreateHires;

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      canCreateHires: json['can_create_hires'] as bool? ?? false,
    );
  }
}
