/// A customer — mirrors Api\Admin\CustomerResource.
class Customer {
  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.nicPassport,
    this.address,
    this.notes,
  });

  final int id;
  final String name;
  final String phone;
  final String? email;
  final String? nicPassport;
  final String? address;
  final String? notes;

  static String? _orNull(dynamic value) {
    final text = value as String?;
    return text != null && text.trim().isNotEmpty ? text : null;
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: _orNull(json['email']),
      nicPassport: _orNull(json['nic_passport']),
      address: _orNull(json['address']),
      notes: _orNull(json['notes']),
    );
  }
}

/// A page of the customer list from GET /admin/customers.
class CustomerPage {
  const CustomerPage({required this.customers, required this.currentPage, required this.lastPage});

  final List<Customer> customers;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;

  factory CustomerPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>?;
    return CustomerPage(
      customers: (json['data'] as List<dynamic>? ?? []).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList(),
      currentPage: (meta?['current_page'] as int?) ?? 1,
      lastPage: (meta?['last_page'] as int?) ?? 1,
    );
  }
}
