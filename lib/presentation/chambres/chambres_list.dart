import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/chambre_charges.dart';
import 'package:habitafrance/data/datasources/chambres.dart';
import 'package:habitafrance/data/datasources/inventaire.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/data/models/chambre_charge.dart';
import 'package:habitafrance/data/models/chambre_disponibilite.dart';
import 'package:habitafrance/data/models/filter_state.dart';
import 'package:habitafrance/presentation/chambres/chambre_card.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

export 'package:habitafrance/data/models/filter_state.dart' show BailTypeFilter;

/// Grid pública de quartos disponíveis com suporte a filtros avançados.
class ChambresList extends StatefulWidget {
  final String filter;
  final ChambreFilter chambreFilter;
  final ValueChanged<List<ChambreModel>>? onDataLoaded;
  /// Si fourni, intercepte le tap sur un card au lieu d'appeler pushNamed.
  final ValueChanged<int>? onTapChambre;
  /// true = la grille s'insère dans un parent déjà scrollable (ex. section
  /// combinée « Location + Colocations » de la home page) : pas de scroll
  /// propre, hauteur = contenu.
  final bool shrinkWrap;

  const ChambresList({
    super.key,
    this.filter = '',
    this.chambreFilter = ChambreFilter.empty,
    this.onDataLoaded,
    this.onTapChambre,
    this.shrinkWrap = false,
  });

  @override
  State<ChambresList> createState() => _ChambresListState();
}

class _ChambresListState extends State<ChambresList> {
  late Future<_ListData> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadData();
  }

  Future<_ListData> _loadData() async {
    final chambres = await ChambresDatasource.listAll();
    widget.onDataLoaded?.call(chambres);
    final ids = chambres.map((c) => c.id).toList();
    final chargesMap = await ChambreChargesDatasource.listByChambres(ids);
    final equipMap = await InventaireDatasource.annonceLabelsByChambre(ids);
    final dispoMap = await ChambresDatasource.disponibiliteByIds(ids);
    return _ListData(
      chambres: chambres,
      chargesMap: chargesMap,
      equipMap: equipMap,
      dispoMap: dispoMap,
    );
  }

  bool _matches(
    ChambreModel c,
    List<ChambreChargeModel> charges,
    List<String> equip,
    ChambreDisponibiliteModel? dispo,
  ) {
    final f = widget.chambreFilter;

    // Disponibilité : par défaut les chambres louées restent visibles.
    if (f.masquerLouees && dispo != null && !dispo.disponible) return false;
    if (f.disponibleAPartirDe != null) {
      if (dispo == null || !dispo.disponibleAvant(f.disponibleAPartirDe!)) {
        return false;
      }
    }

    // Filtro de texto da barra de busca
    final text = widget.filter.toLowerCase();
    if (text.isNotEmpty) {
      final inName = c.roomName.toLowerCase().contains(text);
      final inImm = c.immeubleName?.toLowerCase().contains(text) ?? false;
      final inAddr = c.immeubleAddress?.toLowerCase().contains(text) ?? false;
      if (!inName && !inImm && !inAddr) return false;
    }

    // Équipements (AND: todos os chips selecionados devem estar presentes)
    if (f.equipements.isNotEmpty &&
        !f.equipements.every((name) => equip.contains(name))) {
      return false;
    }

    // Localização (substring case-insensitive)
    if (f.city.isNotEmpty) {
      final match = c.immeubleCity?.toLowerCase().contains(f.city.toLowerCase()) ?? false;
      if (!match) return false;
    }
    if (f.region.isNotEmpty) {
      final match = c.immeubleRegion?.toLowerCase().contains(f.region.toLowerCase()) ?? false;
      if (!match) return false;
    }
    if (f.department.isNotEmpty) {
      final match = c.immeubleDepartment?.toLowerCase().contains(f.department.toLowerCase()) ?? false;
      if (!match) return false;
    }

    if (f.bailType == BailTypeFilter.collectif && !c.immeubleBailLocation) return false;
    if (f.bailType == BailTypeFilter.individuel && !c.immeubleBailIndividuel) return false;

    // Location meublée / non meublée
    if (f.meuble != null && c.immeubleLocationMeuble != f.meuble) return false;

    // Type d'immeuble
    if (f.immeubleTypeId != null && c.immeubleTypeId != f.immeubleTypeId) return false;

    // Surface m²
    if (f.m2Min != null && (c.m2 == null || c.m2! < f.m2Min!)) return false;
    if (f.m2Max != null && (c.m2 == null || c.m2! > f.m2Max!)) return false;

    // Prix loyer
    if (f.prixMin != null && (c.prixLoyer == null || c.prixLoyer! < f.prixMin!)) return false;
    if (f.prixMax != null && (c.prixLoyer == null || c.prixLoyer! > f.prixMax!)) return false;

    // Charges
    if (f.avecCharges != null) {
      final hasInclus = charges.any((ch) => ch.type == 'inclus');
      if (f.avecCharges! && !hasInclus) return false;
      if (!f.avecCharges! && hasInclus) return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ListData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return SizedBox(
            height: 240,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text('Erreur : ${snapshot.error}', style: AppTypography.bodyMd),
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final filtered = data.chambres
            .where((c) => _matches(
                  c,
                  data.chargesMap[c.id] ?? [],
                  data.equipMap[c.id] ?? [],
                  data.dispoMap[c.id],
                ))
            .toList();

        if (filtered.isEmpty) {
          return SizedBox(
            height: 240,
            child: Center(
              child: Text(
                widget.filter.isNotEmpty || !widget.chambreFilter.isEmpty
                    ? 'Aucune chambre ne correspond aux filtres.'
                    : 'Aucune chambre disponible.',
                style: AppTypography.bodyLg,
              ),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: widget.shrinkWrap,
          physics:
              widget.shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            mainAxisExtent: 420,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final chambre = filtered[index];
            final charges = data.chargesMap[chambre.id] ?? [];
            return ChambreCard(
              chambre: chambre,
              equipementLabels: data.equipMap[chambre.id] ?? const [],
              charges: charges,
              disponibilite: data.dispoMap[chambre.id],
              onTap: () {
                if (widget.onTapChambre != null) {
                  widget.onTapChambre!(chambre.id);
                } else {
                  Navigator.of(context).pushNamed('/chambre', arguments: chambre.id);
                }
              },
            );
          },
        );
      },
    );
  }
}

class _ListData {
  final List<ChambreModel> chambres;
  final Map<int, List<ChambreChargeModel>> chargesMap;
  final Map<int, List<String>> equipMap;
  final Map<int, ChambreDisponibiliteModel> dispoMap;
  _ListData({
    required this.chambres,
    required this.chargesMap,
    required this.equipMap,
    required this.dispoMap,
  });
}
