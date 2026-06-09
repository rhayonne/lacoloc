import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/reference.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/filter_state.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_card.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

export 'package:lacoloc_front/data/models/filter_state.dart' show BailTypeFilter;

/// Grid pública de quartos disponíveis com suporte a filtros avançados.
class ChambresList extends StatefulWidget {
  final String filter;
  final ChambreFilter chambreFilter;
  final ValueChanged<List<ChambreModel>>? onDataLoaded;

  const ChambresList({
    super.key,
    this.filter = '',
    this.chambreFilter = ChambreFilter.empty,
    this.onDataLoaded,
  });

  @override
  State<ChambresList> createState() => _ChambresListState();
}

class _ChambresListState extends State<ChambresList> {
  late Future<List<ChambreModel>> _future;

  /// Mapa optionId → nom (Wifi, Lit double…) para rotular as options no card.
  /// Carregado uma vez (cache de [ReferenceDatasource]) — evita fetch por card.
  Map<int, String> _optionNames = const {};

  @override
  void initState() {
    super.initState();
    _loadOptionNames();
    _future = ChambresDatasource.listAll().then((data) {
      widget.onDataLoaded?.call(data);
      return data;
    });
  }

  Future<void> _loadOptionNames() async {
    final opts = await ReferenceDatasource.roomOptions();
    if (!mounted) return;
    setState(() => _optionNames = {for (final o in opts) o.id: o.name});
  }

  bool _matches(ChambreModel c) {
    final f = widget.chambreFilter;

    // Filtro de texto da barra de busca
    final text = widget.filter.toLowerCase();
    if (text.isNotEmpty) {
      final inName = c.roomName.toLowerCase().contains(text);
      final inImm = c.immeubleName?.toLowerCase().contains(text) ?? false;
      final inAddr =
          c.immeubleAddress?.toLowerCase().contains(text) ?? false;
      if (!inName && !inImm && !inAddr) return false;
    }

    // Équipements (AND: todos os chips selecionados devem estar presentes)
    if (f.optionIds.isNotEmpty &&
        !f.optionIds.every((id) => c.selectedOptionIds.contains(id))) {
      return false;
    }

    // Localização (substring case-insensitive)
    if (f.city.isNotEmpty) {
      final match =
          c.immeubleCity?.toLowerCase().contains(f.city.toLowerCase()) ??
              false;
      if (!match) return false;
    }
    if (f.region.isNotEmpty) {
      final match = c.immeubleRegion
              ?.toLowerCase()
              .contains(f.region.toLowerCase()) ??
          false;
      if (!match) return false;
    }
    if (f.department.isNotEmpty) {
      final match = c.immeubleDepartment
              ?.toLowerCase()
              .contains(f.department.toLowerCase()) ??
          false;
      if (!match) return false;
    }

    if (f.bailType == BailTypeFilter.collectif && !c.immeubleBailCollectif) {
      return false;
    }
    if (f.bailType == BailTypeFilter.individuel && !c.immeubleBailIndividuel) {
      return false;
    }

    // Location meublée / non meublée
    if (f.meuble != null && c.immeubleLocationMeuble != f.meuble) return false;

    // Type d'immeuble
    if (f.immeubleTypeId != null && c.immeubleTypeId != f.immeubleTypeId) {
      return false;
    }

    // Surface m²
    if (f.m2Min != null && (c.m2 == null || c.m2! < f.m2Min!)) return false;
    if (f.m2Max != null && (c.m2 == null || c.m2! > f.m2Max!)) return false;

    // Prix loyer
    if (f.prixMin != null &&
        (c.prixLoyer == null || c.prixLoyer! < f.prixMin!)) {
      return false;
    }
    if (f.prixMax != null &&
        (c.prixLoyer == null || c.prixLoyer! > f.prixMax!)) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ChambreModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                'Erreur : ${snapshot.error}',
                style: AppTypography.bodyMd,
              ),
            ),
          );
        }

        final all = snapshot.data ?? [];
        final filtered = all.where(_matches).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Text(
              widget.filter.isNotEmpty || !widget.chambreFilter.isEmpty
                  ? 'Aucune chambre ne correspond aux filtres.'
                  : 'Aucune chambre disponible.',
              style: AppTypography.bodyLg,
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            mainAxisExtent: 410,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final chambre = filtered[index];
            return ChambreCard(
              chambre: chambre,
              optionNames: _optionNames,
              onTap: () => Navigator.of(context)
                  .pushNamed('/chambre', arguments: chambre.id),
            );
          },
        );
      },
    );
  }
}
