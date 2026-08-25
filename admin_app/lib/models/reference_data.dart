/// Simple id/name pairs used to populate the Create Hire screen's dropdowns
/// — matches Api\Admin\HireController::referenceData()'s shape.
class NamedOption {
  const NamedOption({required this.id, required this.name, this.subtitle});

  final int id;
  final String name;
  final String? subtitle;
}

class ReferenceData {
  const ReferenceData({
    required this.drivers,
    required this.vehicles,
    required this.customers,
    required this.packages,
  });

  final List<NamedOption> drivers;
  final List<NamedOption> vehicles;
  final List<NamedOption> customers;
  final List<NamedOption> packages;

  factory ReferenceData.fromJson(Map<String, dynamic> json) {
    return ReferenceData(
      drivers: _list(json['drivers'], nameKey: 'name'),
      vehicles: _list(json['vehicles'], nameKey: 'model'),
      customers: _list(json['customers'], nameKey: 'name', subtitleKey: 'phone'),
      packages: _list(json['packages'], nameKey: 'name'),
    );
  }

  static List<NamedOption> _list(
    dynamic raw, {
    required String nameKey,
    String? subtitleKey,
  }) {
    return (raw as List<dynamic>? ?? [])
        .map((e) {
          final map = e as Map<String, dynamic>;
          return NamedOption(
            id: map['id'] as int,
            name: map[nameKey] as String? ?? '',
            subtitle: subtitleKey != null ? map[subtitleKey] as String? : null,
          );
        })
        .toList();
  }
}
