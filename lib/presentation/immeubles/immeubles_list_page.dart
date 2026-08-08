import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/chambres.dart';
import 'package:habitafrance/data/datasources/inventaire.dart';
import 'package:habitafrance/data/datasources/immeubles.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/data/models/immeubles.dart';
import 'package:habitafrance/presentation/immeubles/immeuble_card.dart';
import 'package:habitafrance/presentation/widgets/filter_panel.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Page publique listant les immeubles actifs qui ont au moins une chambre active.
/// Filtre géré ici (via [FilterPanel]) ; la grille elle-même est [ImmeublesGrid].
class ImmeublesListPage extends StatefulWidget {
  /// Ouverture de la fiche détail (rendue dans le cadre principal). Si null,
  /// la carte n'est pas cliquable.
  final void Function(int immeubleId)? onTapImmeuble;

  const ImmeublesListPage({super.key, this.onTapImmeuble});

  @override
  State<ImmeublesListPage> createState() => _ImmeublesListPageState();
}

class _ImmeublesListPageState extends State<ImmeublesListPage> {
  ChambreFilter _filter = ChambreFilter.empty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilterPanel(
          filter: _filter,
          onChanged: (f) => setState(() => _filter = f),
          modules: const {
            FilterModule.localisation,
            FilterModule.bail,
            FilterModule.meuble,
            FilterModule.typeImmeuble,
            FilterModule.equipements,
          },
        ),
        Expanded(
          child: ImmeublesGrid(
            filter: _filter,
            onTapImmeuble: widget.onTapImmeuble,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Grille d'immeubles actifs (au moins une chambre active), filtrée par un
/// [ChambreFilter] externe — réutilisable ailleurs qu'à l'intérieur
/// d'[ImmeublesListPage] (ex. section « Location » de la home page, où le
/// filtre est partagé avec la grille de chambres via un [FilterPanel] unique).
class ImmeublesGrid extends StatefulWidget {
  final ChambreFilter filter;

  /// Ouverture de la fiche détail (rendue dans le cadre principal). Si null,
  /// la carte n'est pas cliquable.
  final void Function(int immeubleId)? onTapImmeuble;

  /// true = la grille s'insère dans un parent déjà scrollable : pas de scroll
  /// propre, hauteur = contenu.
  final bool shrinkWrap;

  const ImmeublesGrid({
    super.key,
    required this.filter,
    this.onTapImmeuble,
    this.shrinkWrap = false,
  });

  @override
  State<ImmeublesGrid> createState() => _ImmeublesGridState();
}

class _ImmeublesGridState extends State<ImmeublesGrid> {
  late Future<List<ImmeublesModel>> _future;

  /// immeubleId → union des équipements (« dans l'annonce ») de ses chambres
  /// actives (pour le filtre `équipements` côté immeubles).
  Map<int, Set<String>> _immeubleOptions = const {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ImmeublesModel>> _load() async {
    final results = await Future.wait([
      ImmeublesDatasource.listAll(),
      ChambresDatasource.listAll(),
    ]);
    final immeubles = results[0] as List<ImmeublesModel>;
    final chambres = results[1] as List<ChambreModel>;

    // ids de imóveis com ao menos uma chambre ativa + mapa
    // immeubleId → équipements (nomes) « dans l'annonce » das suas chambres.
    final activeIds = <int>{};
    final activeChambres = chambres.where((c) => c.isActive).toList();
    for (final c in activeChambres) {
      activeIds.add(c.immeubleId);
    }
    final equipByChambre = await InventaireDatasource.annonceLabelsByChambre(
        activeChambres.map((c) => c.id).toList());
    final optsByImmeuble = <int, Set<String>>{};
    for (final c in activeChambres) {
      final labels = equipByChambre[c.id];
      if (labels == null || labels.isEmpty) continue;
      optsByImmeuble.putIfAbsent(c.immeubleId, () => <String>{}).addAll(labels);
    }
    _immeubleOptions = optsByImmeuble;

    // Apenas imóveis com pelo menos uma chambre activa
    return immeubles.where((i) => activeIds.contains(i.id)).toList();
  }

  bool _matchesFilter(ImmeublesModel imm) {
    final f = widget.filter;
    if (f.city.isNotEmpty) {
      if (!(imm.city?.toLowerCase().contains(f.city.toLowerCase()) ?? false)) {
        return false;
      }
    }
    if (f.region.isNotEmpty) {
      if (!(imm.region?.toLowerCase().contains(f.region.toLowerCase()) ??
          false)) {
        return false;
      }
    }
    if (f.department.isNotEmpty) {
      if (!(imm.department
              ?.toLowerCase()
              .contains(f.department.toLowerCase()) ??
          false)) {
        return false;
      }
    }
    if (f.bailType == BailTypeFilter.collectif && !imm.bailLocation) {
      return false;
    }
    if (f.bailType == BailTypeFilter.individuel && !imm.bailIndividuel) {
      return false;
    }
    if (f.meuble != null && imm.locationMeuble != f.meuble) return false;
    if (f.immeubleTypeId != null && imm.typeId != f.immeubleTypeId) {
      return false;
    }
    if (f.equipements.isNotEmpty) {
      final opts = _immeubleOptions[imm.id] ?? const <String>{};
      if (!f.equipements.every(opts.contains)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ImmeublesModel>>(
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
                child: Text('Erreur : ${snapshot.error}',
                    style: AppTypography.bodyMd),
              ),
            ),
          );
        }

        final all = snapshot.data ?? [];
        final filtered =
            widget.filter.isEmpty ? all : all.where(_matchesFilter).toList();

        if (filtered.isEmpty) {
          return SizedBox(
            height: 240,
            child: Center(
              child: Text(
                widget.filter.isEmpty
                    ? 'Aucun immeuble disponible.'
                    : 'Aucun immeuble ne correspond aux filtres.',
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
            final imm = filtered[index];
            return ImmeubleCard(
              immeuble: imm,
              onTap: () => widget.onTapImmeuble?.call(imm.id),
            );
          },
        );
      },
    );
  }
}
