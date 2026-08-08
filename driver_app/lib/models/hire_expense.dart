class HireExpense {
  /// Mirrors the backend's `HireExpense::CATEGORIES`, for places (like the
  /// salary breakdown) that only have a raw category key, not a full
  /// [HireExpense] instance with its own [categoryLabel].
  static const categoryLabels = <String, String>{
    'fuel': 'Fuel',
    'repair': 'Vehicle Repair',
    'emergency': 'Emergency',
    'highway': 'Highway Charges',
    'food': 'Driver Foods',
    'room': 'Room Charges',
    'parking': 'Parking Tickets',
    'others': 'Others',
  };

  static String labelFor(String category) => categoryLabels[category] ?? category;

  final int id;
  final int? hireId;
  final String? hireTourTypeLabel;
  final String category;
  final String categoryLabel;
  final double amount;
  final String? receiptUrl;
  final DateTime? createdAt;

  HireExpense({
    required this.id,
    this.hireId,
    this.hireTourTypeLabel,
    required this.category,
    required this.categoryLabel,
    required this.amount,
    this.receiptUrl,
    this.createdAt,
  });

  factory HireExpense.fromJson(Map<String, dynamic> json) {
    return HireExpense(
      id: json['id'] as int,
      hireId: json['hire_id'] as int?,
      hireTourTypeLabel: json['hire_tour_type_label'] as String?,
      category: json['category'] as String,
      categoryLabel: json['category_label'] as String,
      amount: (json['amount'] as num).toDouble(),
      receiptUrl: json['receipt_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
