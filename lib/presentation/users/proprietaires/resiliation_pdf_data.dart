import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';

/// Une ligne de facture « En litige » imputée au locataire (hors vétusté).
class LitigeFactureInfo {
  final String fournisseur;
  final String typeFacture;
  final double montantTtc;
  const LitigeFactureInfo({
    required this.fournisseur,
    required this.typeFacture,
    required this.montantTtc,
  });
}

/// Un décompte de vétusté (résumé) lié au sortie.
class VetusteDecompteInfo {
  final String? titre;
  final double totalMontant;
  const VetusteDecompteInfo({this.titre, required this.totalMontant});
}

/// Données chargées pour le PDF « Acte de résiliation et sortie de bail »,
/// généré une fois le bail résilié ([EtatDesLieuxDatasource.resilierBail]).
/// Réunit l'entrée, la sortie couplée et l'acompte de la caution — mêmes
/// règles que [EtatDesLieuxDatasource.resilierBail]'s `_settleCaution`, mais
/// en lecture seule (n'insère rien).
class ResiliationPdfData {
  final EtatDesLieuxModel entree;
  final EtatDesLieuxModel? sortie;

  final double? cautionMontant;
  final bool cautionRecue;
  final List<VetusteDecompteInfo> vetusteDecomptes;
  final List<LitigeFactureInfo> factureLitiges;

  /// Ligne `Recettes` de remboursement (sens='payer') déjà générée, si elle
  /// existe (créée automatiquement par `resilierBail` quand il n'y avait
  /// aucune déduction).
  final double? refundMontant;
  final bool refundPaye;

  const ResiliationPdfData({
    required this.entree,
    required this.sortie,
    required this.cautionMontant,
    required this.cautionRecue,
    required this.vetusteDecomptes,
    required this.factureLitiges,
    required this.refundMontant,
    required this.refundPaye,
  });

  double get vetusteTotal =>
      vetusteDecomptes.fold(0.0, (s, d) => s + d.totalMontant);
  double get litigeTotal =>
      factureLitiges.fold(0.0, (s, f) => s + f.montantTtc);
  double get deductions => vetusteTotal + litigeTotal;

  /// Montant net à rembourser au locataire (caution − déductions, ≥ 0).
  /// `null` si aucune caution n'a été reçue.
  double? get netARembourser {
    final c = cautionMontant;
    if (c == null) return null;
    final net = c - deductions;
    return net < 0 ? 0 : net;
  }

  bool get sansLitige => deductions <= 0 && !entree.isAvenant;

  static Future<ResiliationPdfData> fromEntree(int entreeId) async {
    final db = Supabase.instance.client;
    final entree = await EtatDesLieuxDatasource.findById(entreeId);
    if (entree == null) {
      throw Exception("État des lieux d'entrée #$entreeId introuvable");
    }
    final sortie = await EtatDesLieuxDatasource.findSortieForEntree(entreeId);

    final cautionRow = await db
        .from('Recettes')
        .select('montant, statut')
        .eq('etat_de_lieux_id', entreeId)
        .ilike('notes', 'Dépôt de garantie%')
        .maybeSingle();
    final cautionMontant = (cautionRow?['montant'] as num?)?.toDouble();
    final cautionRecue = cautionRow?['statut'] == 'recu';

    var vetusteDecomptes = <VetusteDecompteInfo>[];
    if (sortie != null) {
      final rows = await db
          .from('vetuste_decompte')
          .select('titre, total_montant')
          .eq('etat_de_lieux_id', sortie.id);
      vetusteDecomptes = (rows as List)
          .map((d) => VetusteDecompteInfo(
                titre: d['titre'] as String?,
                totalMontant: (d['total_montant'] as num?)?.toDouble() ?? 0,
              ))
          .where((d) => d.totalMontant > 0)
          .toList();
    }

    var factureLitiges = <LitigeFactureInfo>[];
    if (entree.chambreId != null) {
      final rows = await db
          .from('Factures')
          .select('fournisseur, type_facture, montant_ttc')
          .eq('chambre_id', entree.chambreId!)
          .eq('statut', 'En litige');
      factureLitiges = (rows as List)
          .map((f) => LitigeFactureInfo(
                fournisseur: f['fournisseur'] as String? ?? '—',
                typeFacture: f['type_facture'] as String? ?? '—',
                montantTtc: (f['montant_ttc'] as num?)?.toDouble() ?? 0,
              ))
          .toList();
    }

    final refundRow = await db
        .from('Recettes')
        .select('montant, statut')
        .eq('etat_de_lieux_id', entreeId)
        .eq('sens', 'payer')
        .ilike('notes', 'Remboursement de la caution%')
        .maybeSingle();

    return ResiliationPdfData(
      entree: entree,
      sortie: sortie,
      cautionMontant: cautionMontant,
      cautionRecue: cautionRecue,
      vetusteDecomptes: vetusteDecomptes,
      factureLitiges: factureLitiges,
      refundMontant: (refundRow?['montant'] as num?)?.toDouble(),
      refundPaye: refundRow?['statut'] == 'recu',
    );
  }
}
