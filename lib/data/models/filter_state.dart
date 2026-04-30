/// Estado imutável dos filtros avançados de pesquisa.
class ChambreFilter {
  final Set<int> optionIds;
  final String city;
  final String region;
  final String department;

  const ChambreFilter({
    this.optionIds = const {},
    this.city = '',
    this.region = '',
    this.department = '',
  });

  bool get isEmpty =>
      optionIds.isEmpty &&
      city.isEmpty &&
      region.isEmpty &&
      department.isEmpty;

  int get activeCount =>
      (optionIds.isNotEmpty ? 1 : 0) +
      (city.isNotEmpty ? 1 : 0) +
      (region.isNotEmpty ? 1 : 0) +
      (department.isNotEmpty ? 1 : 0);

  ChambreFilter copyWith({
    Set<int>? optionIds,
    String? city,
    String? region,
    String? department,
  }) =>
      ChambreFilter(
        optionIds: optionIds ?? this.optionIds,
        city: city ?? this.city,
        region: region ?? this.region,
        department: department ?? this.department,
      );

  static const empty = ChambreFilter();
}
