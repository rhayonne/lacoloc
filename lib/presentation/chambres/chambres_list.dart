import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/filter_state.dart';
import 'package:lacoloc_front/presentation/chambres/chambre_card.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

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

  @override
  void initState() {
    super.initState();
    _future = ChambresDatasource.listAll().then((data) {
      widget.onDataLoaded?.call(data);
      return data;
    });
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
            mainAxisExtent: 380,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final chambre = filtered[index];
            return ChambreCard(
              chambre: chambre,
              onTap: () => Navigator.of(context)
                  .pushNamed('/chambre', arguments: chambre.id),
            );
          },
        );
      },
    );
  }
}
