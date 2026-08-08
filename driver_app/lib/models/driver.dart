class Driver {
  final int id;
  final String name;
  final String email;
  final String license;
  final String contactNumber;
  final String? additionalPhoneNumber;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.license,
    required this.contactNumber,
    this.additionalPhoneNumber,
  });

  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      license: json['license'] as String,
      contactNumber: json['contact_number'] as String,
      additionalPhoneNumber: json['additional_phone_number'] as String?,
    );
  }
}
