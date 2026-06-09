/// Tipo de bail pour le filtre. [null] = pas de filtre.
enum BailTypeFilter { collectif, individuel }

/// Estado imutável dos filtros avançados de pesquisa.
class ChambreFilter {
  final Set<int> optionIds;
  final String city;
  final String region;
  final String department;
  final BailTypeFilter? bailType;

  /// Location meublée : null = indifférent ; true = meublée ; false = non meublée.
  final bool? meuble;

  /// Type d'immeuble (id de `Immeuble_Types_Reference`) ; null = indifférent.
  final int? immeubleTypeId;
  final double? m2Min;
  final double? m2Max;
  final double? prixMin;
  final double? prixMax;

  const ChambreFilter({
    this.optionIds = const {},
    this.city = '',
    this.region = '',
    this.department = '',
    this.bailType,
    this.meuble,
    this.immeubleTypeId,
    this.m2Min,
    this.m2Max,
    this.prixMin,
    this.prixMax,
  });

  bool get isEmpty =>
      optionIds.isEmpty &&
      city.isEmpty &&
      region.isEmpty &&
      department.isEmpty &&
      bailType == null &&
      meuble == null &&
      immeubleTypeId == null &&
      m2Min == null &&
      m2Max == null &&
      prixMin == null &&
      prixMax == null;

  int get activeCount =>
      (optionIds.isNotEmpty ? 1 : 0) +
      (city.isNotEmpty ? 1 : 0) +
      (region.isNotEmpty ? 1 : 0) +
      (department.isNotEmpty ? 1 : 0) +
      (bailType != null ? 1 : 0) +
      (meuble != null ? 1 : 0) +
      (immeubleTypeId != null ? 1 : 0) +
      (m2Min != null || m2Max != null ? 1 : 0) +
      (prixMin != null || prixMax != null ? 1 : 0);

  ChambreFilter copyWith({
    Set<int>? optionIds,
    String? city,
    String? region,
    String? department,
    Object? bailType = _sentinel,
    Object? meuble = _sentinel,
    Object? immeubleTypeId = _sentinel,
    Object? m2Min = _sentinel,
    Object? m2Max = _sentinel,
    Object? prixMin = _sentinel,
    Object? prixMax = _sentinel,
  }) =>
      ChambreFilter(
        optionIds: optionIds ?? this.optionIds,
        city: city ?? this.city,
        region: region ?? this.region,
        department: department ?? this.department,
        bailType: bailType == _sentinel
            ? this.bailType
            : bailType as BailTypeFilter?,
        meuble: meuble == _sentinel ? this.meuble : meuble as bool?,
        immeubleTypeId: immeubleTypeId == _sentinel
            ? this.immeubleTypeId
            : immeubleTypeId as int?,
        m2Min: m2Min == _sentinel ? this.m2Min : m2Min as double?,
        m2Max: m2Max == _sentinel ? this.m2Max : m2Max as double?,
        prixMin: prixMin == _sentinel ? this.prixMin : prixMin as double?,
        prixMax: prixMax == _sentinel ? this.prixMax : prixMax as double?,
      );

  static const empty = ChambreFilter();
}

const _sentinel = Object();
