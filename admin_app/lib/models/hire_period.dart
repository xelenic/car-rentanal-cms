import 'package:intl/intl.dart';

/// A year — or one month of a year — a vehicle's hires can be narrowed to.
class HirePeriod {
  const HirePeriod(this.year, [this.month]);

  final int year;

  /// 1–12, or null for the whole year.
  final int? month;

  /// "September 2026", or just "2026" for a whole year.
  String get label => month == null ? '$year' : DateFormat('MMMM y').format(DateTime(year, month!));

  /// The query parameters the API takes.
  Map<String, String> get query => {'year': '$year', if (month != null) 'month': '$month'};

  @override
  bool operator ==(Object other) => other is HirePeriod && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

/// The periods a vehicle has hires in — what the filter offers, so it never
/// lists a month with nothing in it.
class PeriodOptions {
  const PeriodOptions({this.years = const [], this.monthsByYear = const {}});

  final List<int> years;
  final Map<int, List<int>> monthsByYear;

  List<int> monthsOf(int year) => monthsByYear[year] ?? const [];

  factory PeriodOptions.fromJson(Map<String, dynamic> json) {
    final byYear = json['months_by_year'];
    return PeriodOptions(
      years: (json['years'] as List<dynamic>? ?? []).map((e) => (e as num).toInt()).toList(),
      monthsByYear: {
        if (byYear is Map<String, dynamic>)
          for (final entry in byYear.entries)
            int.parse(entry.key): (entry.value as List<dynamic>).map((e) => (e as num).toInt()).toList(),
      },
    );
  }
}
