/// Tipo de bail pour le filtre. [null] = pas de filtre.
enum BailTypeFilter { collectif, individuel }

/// Estado imutável dos filtros avançados de pesquisa.
class ChambreFilter {
  final Set<int> optionIds;
  final String city;
  final String region;
  final String department;
  final BailTypeFilter? bailType;

  const ChambreFilter({
    this.optionIds = const {},
    this.city = '',
    this.region = '',
    this.department = '',
    this.bailType,
  });

  bool get isEmpty =>
      optionIds.isEmpty &&
      city.isEmpty &&
      region.isEmpty &&
      department.isEmpty &&
      bailType == null;

  int get activeCount =>
      (optionIds.isNotEmpty ? 1 : 0) +
      (city.isNotEmpty ? 1 : 0) +
      (region.isNotEmpty ? 1 : 0) +
      (department.isNotEmpty ? 1 : 0) +
      (bailType != null ? 1 : 0);

  ChambreFilter copyWith({
    Set<int>? optionIds,
    String? city,
    String? region,
    String? department,
    Object? bailType = _sentinel,
  }) =>
      ChambreFilter(
        optionIds: optionIds ?? this.optionIds,
        city: city ?? this.city,
        region: region ?? this.region,
        department: department ?? this.department,
        bailType: bailType == _sentinel
            ? this.bailType
            : bailType as BailTypeFilter?,
      );

  static const empty = ChambreFilter();
}

const _sentinel = Object();
