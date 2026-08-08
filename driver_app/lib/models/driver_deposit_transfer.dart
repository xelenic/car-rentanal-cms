/// A record of cash the driver has physically deposited to the company's
/// bank account for a given month, evidenced by a photo of the bank slip.
class DriverDepositTransfer {
  final int id;
  final int year;
  final int month;
  final double amount;
  final String? slipUrl;
  final DateTime? createdAt;

  DriverDepositTransfer({
    required this.id,
    required this.year,
    required this.month,
    required this.amount,
    this.slipUrl,
    this.createdAt,
  });

  factory DriverDepositTransfer.fromJson(Map<String, dynamic> json) {
    return DriverDepositTransfer(
      id: json['id'] as int,
      year: json['year'] as int,
      month: json['month'] as int,
      amount: (json['amount'] as num).toDouble(),
      slipUrl: json['slip_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
