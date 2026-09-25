import 'hire.dart';

/// A page of hires plus the total count across all pages, as reported by
/// the API's pagination metadata.
class HirePage {
  final List<Hire> items;
  final int total;

  /// [total] without cancelled hires — what a "Total Hires" figure should show.
  /// A server that predates cancelling doesn't send it, and then nothing was
  /// cancelled, so it is the same as [total].
  final int countedTotal;

  /// Which page this is (from 1) and how many there are. A server that doesn't
  /// page reports a single page.
  final int currentPage;
  final int lastPage;

  HirePage({
    required this.items,
    required this.total,
    int? countedTotal,
    this.currentPage = 1,
    this.lastPage = 1,
  }) : countedTotal = countedTotal ?? total;

  /// More pages follow this one.
  bool get hasMore => currentPage < lastPage;

  factory HirePage.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>;
    final meta = json['meta'] as Map<String, dynamic>?;

    final total = meta != null ? (meta['total'] as num).toInt() : list.length;

    return HirePage(
      items: list.map((e) => Hire.fromJson(e as Map<String, dynamic>)).toList(),
      total: total,
      countedTotal: (json['counted_total'] as num?)?.toInt() ?? total,
      currentPage: (meta?['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta?['last_page'] as num?)?.toInt() ?? 1,
    );
  }
}
