import 'hire.dart';

/// A page of hires plus the total count across all pages, as reported by
/// the API's pagination metadata.
class HirePage {
  final List<Hire> items;
  final int total;

  HirePage({required this.items, required this.total});

  factory HirePage.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>;
    final meta = json['meta'] as Map<String, dynamic>?;

    return HirePage(
      items: list.map((e) => Hire.fromJson(e as Map<String, dynamic>)).toList(),
      total: meta != null ? (meta['total'] as num).toInt() : list.length,
    );
  }
}
