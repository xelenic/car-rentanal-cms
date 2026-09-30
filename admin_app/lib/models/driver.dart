/// A driver on the roster — mirrors Api\Admin\DriverResource. Never carries
/// a password; that's write-only (see ApiClient.createDriver/updateDriver).
class Driver {
  const Driver({
    required this.id,
    required this.name,
    required this.license,
    required this.contactNumber,
    this.additionalPhoneNumber,
    required this.email,
  });

  final int id;
  final String name;
  final String license;
  final String contactNumber;
  final String? additionalPhoneNumber;
  final String email;

  factory Driver.fromJson(Map<String, dynamic> json) {
    final additional = json['additional_phone_number'] as String?;
    return Driver(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      license: json['license'] as String? ?? '',
      contactNumber: json['contact_number'] as String? ?? '',
      additionalPhoneNumber: additional != null && additional.trim().isNotEmpty ? additional : null,
      email: json['email'] as String? ?? '',
    );
  }
}

/// A page of the roster from GET /admin/drivers.
class DriverPage {
  const DriverPage({required this.drivers, required this.currentPage, required this.lastPage});

  final List<Driver> drivers;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory DriverPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>?;
    return DriverPage(
      drivers: (json['data'] as List<dynamic>? ?? []).map((e) => Driver.fromJson(e as Map<String, dynamic>)).toList(),
      currentPage: (meta?['current_page'] as int?) ?? 1,
      lastPage: (meta?['last_page'] as int?) ?? 1,
    );
  }
}
