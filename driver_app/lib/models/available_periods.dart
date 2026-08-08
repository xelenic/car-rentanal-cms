/// The distinct years/months for which the driver has hire data, as
/// reported by the API. Used to populate the Home screen's history filter
/// with only periods that actually contain something.
class AvailablePeriods {
  final List<int> years;
  final Map<int, List<int>> monthsByYear;

  AvailablePeriods({required this.years, required this.monthsByYear});

  factory AvailablePeriods.fromJson(Map<String, dynamic> json) {
    final years = (json['years'] as List<dynamic>).map((e) => e as int).toList();
    final rawMonths = json['months_by_year'] as Map<String, dynamic>;

    return AvailablePeriods(
      years: years,
      monthsByYear: rawMonths.map(
        (key, value) => MapEntry(
          int.parse(key),
          (value as List<dynamic>).map((e) => e as int).toList(),
        ),
      ),
    );
  }

  List<int> monthsFor(int? year) => year != null ? (monthsByYear[year] ?? const []) : const [];
}
