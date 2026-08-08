import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/chambre_charges.dart';
import 'package:habitafrance/data/datasources/chambres.dart';
import 'package:habitafrance/data/datasources/immeubles.dart';
import 'package:habitafrance/data/datasources/inventaire.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/data/models/chambre_charge.dart';
import 'package:habitafrance/data/models/chambre_disponibilite.dart';
import 'package:habitafrance/data/models/filter_state.dart';
import 'package:habitafrance/data/models/immeubles.dart';
import 'package:habitafrance/presentation/chambres/chambre_card.dart';
import 'package:habitafrance/presentation/immeubles/immeuble_card.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Grille unique mélangeant « Location » (immeubles entiers, bail location) et
/// « Colocation » (chambres individuelles, bail individuel) — chaque carte
/// porte son propre badge de catégorie ([ImmeubleCard]/[ChambreCard],
/// `showTypeBadge: true`), pas de section séparée. Les deux catégories sont
/// togglables indépendamment via [showLocation]/[showColocation].
class HomeListingsGrid extends StatefulWidget {
  final ChambreFilter filter;
  final String searchQuery;
  final bool showLocation;
  final bool showColocation;
  final void Function(int chambreId)? onTapChambre;
  final void Function(int immeubleId)? onTapImmeuble;
  final ValueChanged<List<ChambreModel>>? onChambresLoaded;

  const HomeListingsGrid({
    super.key,
    required this.filter,
    this.searchQuery = '',
    this.showLocation = true,
    this.showColocation = true,
    this.onTapChambre,
    this.onTapImmeuble,
    this.onChambresLoaded,
  });

  @override
  State<HomeListingsGrid> createState() => _HomeListingsGridState();
}

class _HomeListingsGridState extends State<HomeListingsGrid> {
  late Future<_Data> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Data> _load() async {
    final results = await Future.wait([
      ChambresDatasource.listAll(),
      ImmeublesDatasource.listAll(),
    ]);
    final chambres = results[0] as List<ChambreModel>;
    final immeubles = results[1] as List<ImmeublesModel>;
    widget.onChambresLoaded?.call(chambres);

    final ids = chambres.map((c) => c.id).toList();
    final chargesMap = await ChambreChargesDatasource.listByChambres(ids);
    final equipMap = await InventaireDatasource.annonceLabelsByChambre(ids);
    final dispoMap = await ChambresDatasource.disponibiliteByIds(ids);

    // immeubleId → union des équipements « dans l'annonce » de ses chambres
    // actives (filtre `équipements` côté immeubles/Location).
    final activeChambres = chambres.where((c) => c.isActive).toList();
    final activeImmeubleIds = activeChambres.map((c) => c.immeubleId).toSet();
    final immeubleEquip = <int, Set<String>>{};
    for (final c in activeChambres) {
      final labels = equipMap[c.id];
      if (labels == null || labels.isEmpty) continue;
      immeubleEquip
          .putIfAbsent(c.immeubleId, () => <String>{})
          .addAll(labels);
    }
    final activeImmeubles =
        immeubles.where((i) => activeImmeubleIds.contains(i.id)).toList();

    return _Data(
      chambres: chambres,
      immeubles: activeImmeubles,
      chargesMap: chargesMap,
      equipMap: equipMap,
      dispoMap: dispoMap,
      immeubleEquip: immeubleEquip,
    );
  }

  bool _matchesChambre(
    ChambreModel c,
    List<ChambreChargeModel> charges,
    List<String> equip,
    ChambreDisponibiliteModel? dispo,
  ) {
    final f = widget.filter;

    if (f.masquerLouees && dispo != null && !dispo.disponible) return false;
    if (f.disponibleAPartirDe != null) {
      if (dispo == null || !dispo.disponibleAvant(f.disponibleAPartirDe!)) {
        return false;
      }
    }

    final text = widget.searchQuery.toLowerCase();
    if (text.isNotEmpty) {
      final inName = c.roomName.toLowerCase().contains(text);
      final inImm = c.immeubleName?.toLowerCase().contains(text) ?? false;
      final inAddr = c.immeubleAddress?.toLowerCase().contains(text) ?? false;
      if (!inName && !inImm && !inAddr) return false;
    }

    if (f.equipements.isNotEmpty &&
        !f.equipements.every((name) => equip.contains(name))) {
      return false;
    }

    if (f.city.isNotEmpty) {
      final match =
          c.immeubleCity?.toLowerCase().contains(f.city.toLowerCase()) ??
              false;
      if (!match) return false;
    }
    if (f.region.isNotEmpty) {
      final match =
          c.immeubleRegion?.toLowerCase().contains(f.region.toLowerCase()) ??
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

    if (f.meuble != null && c.immeubleLocationMeuble != f.meuble) return false;
    if (f.immeubleTypeId != null && c.immeubleTypeId != f.immeubleTypeId) {
      return false;
    }

    if (f.m2Min != null && (c.m2 == null || c.m2! < f.m2Min!)) return false;
    if (f.m2Max != null && (c.m2 == null || c.m2! > f.m2Max!)) return false;

    if (f.prixMin != null &&
        (c.prixLoyer == null || c.prixLoyer! < f.prixMin!)) {
      return false;
    }
    if (f.prixMax != null &&
        (c.prixLoyer == null || c.prixLoyer! > f.prixMax!)) {
      return false;
    }

    if (f.avecCharges != null) {
      final hasInclus = charges.any((ch) => ch.type == 'inclus');
      if (f.avecCharges! && !hasInclus) return false;
      if (!f.avecCharges! && hasInclus) return false;
    }

    return true;
  }

  bool _matchesImmeuble(ImmeublesModel imm, Set<String> equip) {
    final f = widget.filter;

    final text = widget.searchQuery.toLowerCase();
    if (text.isNotEmpty) {
      final inName = imm.name.toLowerCase().contains(text);
      final inAddr = imm.address?.toLowerCase().contains(text) ?? false;
      if (!inName && !inAddr) return false;
    }

    if (f.city.isNotEmpty) {
      if (!(imm.city?.toLowerCase().contains(f.city.toLowerCase()) ??
          false)) {
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
    if (f.meuble != null && imm.locationMeuble != f.meuble) return false;
    if (f.immeubleTypeId != null && imm.typeId != f.immeubleTypeId) {
      return false;
    }
    if (f.equipements.isNotEmpty && !f.equipements.every(equip.contains)) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Data>(
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

        final data = snapshot.data!;
        final items = <_Item>[];

        if (widget.showColocation) {
          for (final c in data.chambres) {
            if (!c.immeubleBailIndividuel) continue;
            if (!_matchesChambre(
              c,
              data.chargesMap[c.id] ?? const [],
              data.equipMap[c.id] ?? const [],
              data.dispoMap[c.id],
            )) {
              continue;
            }
            items.add(_ChambreItem(c));
          }
        }
        if (widget.showLocation) {
          for (final imm in data.immeubles) {
            if (!imm.bailLocation) continue;
            final equip = data.immeubleEquip[imm.id] ?? const <String>{};
            if (!_matchesImmeuble(imm, equip)) continue;
            items.add(_ImmeubleItem(imm));
          }
        }

        // Tri stable par nom (immeuble / chambre) : les deux catégories se
        // mélangent naturellement dans la grille, sans section ni ordre erratique.
        items.sort((a, b) => a.sortKey.compareTo(b.sortKey));

        if (items.isEmpty) {
          return SizedBox(
            height: 240,
            child: Center(
              child: Text(
                widget.searchQuery.isNotEmpty || !widget.filter.isEmpty
                    ? 'Aucune annonce ne correspond aux filtres.'
                    : 'Aucune annonce disponible.',
                style: AppTypography.bodyLg,
              ),
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 420,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
            mainAxisExtent: 420,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return switch (item) {
              _ChambreItem(chambre: final c) => ChambreCard(
                  chambre: c,
                  equipementLabels: data.equipMap[c.id] ?? const [],
                  charges: data.chargesMap[c.id] ?? const [],
                  disponibilite: data.dispoMap[c.id],
                  showTypeBadge: true,
                  onTap: () => widget.onTapChambre?.call(c.id),
                ),
              _ImmeubleItem(immeuble: final imm) => ImmeubleCard(
                  immeuble: imm,
                  showTypeBadge: true,
                  onTap: () => widget.onTapImmeuble?.call(imm.id),
                ),
            };
          },
        );
      },
    );
  }
}

class _Data {
  final List<ChambreModel> chambres;
  final List<ImmeublesModel> immeubles;
  final Map<int, List<ChambreChargeModel>> chargesMap;
  final Map<int, List<String>> equipMap;
  final Map<int, ChambreDisponibiliteModel> dispoMap;
  final Map<int, Set<String>> immeubleEquip;

  _Data({
    required this.chambres,
    required this.immeubles,
    required this.chargesMap,
    required this.equipMap,
    required this.dispoMap,
    required this.immeubleEquip,
  });
}

sealed class _Item {
  String get sortKey;
}

class _ChambreItem extends _Item {
  final ChambreModel chambre;
  _ChambreItem(this.chambre);

  @override
  String get sortKey =>
      (chambre.immeubleName ?? chambre.roomName).toLowerCase();
}

class _ImmeubleItem extends _Item {
  final ImmeublesModel immeuble;
  _ImmeubleItem(this.immeuble);

  @override
  String get sortKey => immeuble.name.toLowerCase();
}
