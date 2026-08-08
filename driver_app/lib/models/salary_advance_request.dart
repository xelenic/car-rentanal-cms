/// A driver's request to be advanced part of their salary early, reviewed
/// by an admin (pending, approved, or rejected).
class SalaryAdvanceRequest {
  final int id;
  final double amount;
  final String? reason;
  final String status;
  final String statusLabel;
  final String? adminNote;
  final DateTime? reviewedAt;
  final DateTime? createdAt;

  SalaryAdvanceRequest({
    required this.id,
    required this.amount,
    this.reason,
    required this.status,
    required this.statusLabel,
    this.adminNote,
    this.reviewedAt,
    this.createdAt,
  });

  factory SalaryAdvanceRequest.fromJson(Map<String, dynamic> json) {
    return SalaryAdvanceRequest(
      id: json['id'] as int,
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'] as String?,
      status: json['status'] as String,
      statusLabel: json['status_label'] as String,
      adminNote: json['admin_note'] as String?,
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.tryParse(json['reviewed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }
}
