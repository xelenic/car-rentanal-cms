double _number(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

/// Mirrors the backend's `HireExpense::CATEGORIES` — the fixed set a
/// driver-logged expense is filed under, used for the edit form's dropdown.
const driverExpenseCategories = <String, String>{
  'fuel': 'Fuel',
  'repair': 'Vehicle Repair',
  'emergency': 'Emergency',
  'highway': 'Highway Charges',
  'food': 'Driver Foods',
  'room': 'Room Charges',
  'parking': 'Parking Tickets',
  'others': 'Others',
};

/// One expense a driver logged — mirrors Http\Resources\DriverExpenseResource.
/// May or may not be tied to a hire (see HireExpense::CATEGORIES on the
/// backend for the full category set).
class DriverExpense {
  const DriverExpense({
    required this.id,
    this.hireId,
    this.hireTourTypeLabel,
    required this.category,
    required this.categoryLabel,
    required this.amount,
    this.receiptUrl,
    this.createdAt,
  });

  final int id;
  final int? hireId;

  /// Which hire it was logged against, if any ("Day Tour", "Airport Drop"…).
  final String? hireTourTypeLabel;
  final String category;
  final String categoryLabel;
  final double amount;
  final String? receiptUrl;
  final DateTime? createdAt;

  factory DriverExpense.fromJson(Map<String, dynamic> json) {
    return DriverExpense(
      id: json['id'] as int,
      hireId: json['hire_id'] as int?,
      hireTourTypeLabel: json['hire_tour_type_label'] as String?,
      category: json['category'] as String? ?? '',
      categoryLabel: json['category_label'] as String? ?? '',
      amount: _number(json['amount']),
      receiptUrl: json['receipt_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
    );
  }
}

/// Totals of every expense a request's filters matched, not just the page shown.
class DriverExpenseListSummary {
  const DriverExpenseListSummary({this.count = 0, this.total = 0});

  final int count;
  final double total;

  factory DriverExpenseListSummary.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const DriverExpenseListSummary();
    return DriverExpenseListSummary(
      count: (json['count'] as num?)?.toInt() ?? 0,
      total: _number(json['total']),
    );
  }
}

/// A page of a driver's expenses from the paginated
/// /api/admin/drivers/{driver}/expenses endpoint.
class DriverExpensePage {
  const DriverExpensePage({
    required this.expenses,
    required this.currentPage,
    required this.lastPage,
    this.summary = const DriverExpenseListSummary(),
  });

  final List<DriverExpense> expenses;
  final int currentPage;
  final int lastPage;
  final DriverExpenseListSummary summary;

  bool get hasMore => currentPage < lastPage;

  factory DriverExpensePage.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as List<dynamic>? ?? [])
        .map((e) => DriverExpense.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['meta'] as Map<String, dynamic>?;

    return DriverExpensePage(
      expenses: data,
      currentPage: (meta?['current_page'] as int?) ?? 1,
      lastPage: (meta?['last_page'] as int?) ?? 1,
      summary: DriverExpenseListSummary.fromJson(json['summary'] as Map<String, dynamic>?),
    );
  }
}
