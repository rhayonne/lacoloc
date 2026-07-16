import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/models/recette.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Diagnostic de [RecettesDatasource.generateFromBail] /
/// [RecettesDatasource.ensureBailEcheances] — remplace un échec silencieux
/// par une cause explicite affichable à l'écran.
enum EcheanceGenResult {
  generated,
  alreadyExists,
  bailNotFullySigned,
  notOwner,
  edlNotFound,
  notEntree,
  missingDateDebutBail,
  missingLoyer,
  missingDuree,
}

class RecettesDatasource {
  RecettesDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Recettes';
  static const _select =
      '*, Immeubles!immeuble_id(id, name), Chambres!chambre_id(id, room_name), Users_Client!locataire_id(id, full_name)';

  static final _cache = DataCache.instance;
  static const _prefix = CacheKeys.recettes;
  static void _invalidate() => _cache.invalidatePrefix(_prefix);

  // ── Lecture ──────────────────────────────────────────────────────────────

  static Future<List<RecetteModel>> listByOwner(
    String ownerId, {
    bool refresh = false,
  }) {
    return _cache.get('${_prefix}owner:$ownerId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('owner_id', ownerId)
          .order('date_echeance');
      return (rows as List).map((r) => RecetteModel.fromMap(r as Map<String, dynamic>)).toList();
    }, refresh: refresh);
  }

  static Future<List<RecetteModel>> listByLocataire(
    String locataireId, {
    bool refresh = false,
  }) {
    return _cache.get('${_prefix}locataire:$locataireId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .or('locataire_id.eq.$locataireId')
          .order('date_echeance');
      return (rows as List).map((r) => RecetteModel.fromMap(r as Map<String, dynamic>)).toList();
    }, refresh: refresh);
  }

  static Future<List<RecetteModel>> listByEdl(int edlId) async {
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('etat_de_lieux_id', edlId)
        .order('date_echeance');
    return (rows as List).map((r) => RecetteModel.fromMap(r as Map<String, dynamic>)).toList();
  }

  // ── Génération automatique depuis un bail ─────────────────────────────────

  /// Génère les échéances mensuelles pour un EDL d'**entrée** finalisé.
  /// Idempotent : si des recettes existent déjà pour cet EDL, ne fait rien.
  ///
  /// Règle : le locataire paie au début du mois (à l'entrée). La première
  /// échéance = 1er du mois de [dateDebutBail].
  ///
  /// Retourne un diagnostic (`EcheanceGenResult`) au lieu d'échouer en
  /// silence — sans ça, un bail signé sans échéances générées n'affichait
  /// aucune erreur ni indice de la cause (dates de bail manquantes, loyer nul…).
  static Future<EcheanceGenResult> generateFromBail(int edlId) async {
    // Idempotence : ne pas recréer si déjà générées.
    final existing = await _db
        .from(_table)
        .select('id')
        .eq('etat_de_lieux_id', edlId)
        .limit(1);
    if ((existing as List).isNotEmpty) return EcheanceGenResult.alreadyExists;

    final result = await _expectedRowsForBail(edlId);
    if (result.reason != null) return result.reason!;
    final rows = result.rows!;
    if (rows.isEmpty) return EcheanceGenResult.missingDuree;
    await _db.from(_table).insert(rows);
    _invalidate();
    return EcheanceGenResult.generated;
  }

  /// Réinsère les échéances **manquantes** d'un bail (comparaison par
  /// date d'échéance + nature caution/loyer), sans toucher aux existantes
  /// (payées ou non). Utilisé quand une résiliation est **annulée** : les
  /// échéances rognées par `deleteFutureInstallments` sont restaurées —
  /// le guard d'idempotence de [generateFromBail] ne suffit pas car des
  /// recettes antérieures existent toujours.
  static Future<void> regenerateMissingInstallments(int edlId) async {
    final result = await _expectedRowsForBail(edlId);
    final expected = result.rows;
    if (expected == null || expected.isEmpty) return;

    final existing = await _db
        .from(_table)
        .select('id, date_echeance, notes, montant, statut')
        .eq('etat_de_lieux_id', edlId);
    String keyOf(String? date, String? notes) =>
        '${date ?? ''}|${(notes ?? '').startsWith('Dépôt de garantie') ? 'caution' : 'loyer'}';
    final existingByKey = {
      for (final r in (existing as List))
        keyOf(r['date_echeance'] as String?, r['notes'] as String?): r,
    };

    final missing = expected
        .where((r) => !existingByKey.containsKey(
            keyOf(r['date_echeance'] as String?, r['notes'] as String?)))
        .toList();
    if (missing.isNotEmpty) {
      await _db.from(_table).insert(missing);
    }

    // Une résiliation annulée peut avoir laissé le mois du départ **réduit**
    // au prorata (`deleteFutureInstallments(proRata: true)` met à jour la
    // ligne au lieu de la supprimer) — on le remet au montant plein.
    for (final r in expected) {
      final key = keyOf(r['date_echeance'] as String?, r['notes'] as String?);
      final row = existingByKey[key];
      if (row == null || row['statut'] == 'recu') continue;
      final montantAttendu = r['montant'] as double;
      final montantActuel = (row['montant'] as num).toDouble();
      if ((montantActuel - montantAttendu).abs() > 0.001) {
        await _db
            .from(_table)
            .update({'montant': montantAttendu}).eq('id', row['id'] as int);
      }
    }
    _invalidate();
  }

  /// Monte les lignes de recette attendues pour le bail de l'EDL [edlId]
  /// (1 caution + 1 loyer par mois du bail). `reason` non-null si l'EDL
  /// n'est pas une entrée exploitable (pas de date de début, pas de montant,
  /// etc.) — permet d'afficher la cause exacte au lieu d'échouer en silence.
  static Future<({List<Map<String, dynamic>>? rows, EcheanceGenResult? reason})>
      _expectedRowsForBail(int edlId) async {
    // Lire l'EDL complet pour récupérer montant, locataire_id, etc.
    final row = await _db
        .from('etat_de_lieux')
        .select(
            'id, proprietaire_id, locataire_id, immeuble_id, chambre_id, '
            'type_edl, montant, date_debut_bail, date_fin_bail, duree_bail_mois')
        .eq('id', edlId)
        .maybeSingle();

    if (row == null) return (rows: null, reason: EcheanceGenResult.edlNotFound);
    if (row['type_edl'] != 'entree') {
      return (rows: null, reason: EcheanceGenResult.notEntree);
    }
    if (row['date_debut_bail'] == null) {
      return (rows: null, reason: EcheanceGenResult.missingDateDebutBail);
    }

    final startDate = DateTime.parse(row['date_debut_bail'] as String);
    // Montant de l'échéance = loyer mensuel. La colonne `montant` de l'EDL
    // n'est en pratique pas renseignée par les pages de saisie → on retombe
    // sur le loyer de la chambre (bail individuel) ou de l'immeuble (location).
    double? montant = (row['montant'] as num?)?.toDouble();
    montant ??= await _loyerMensuel(
      chambreId: row['chambre_id'] as int?,
      immeubleId: row['immeuble_id'] as int?,
    );
    if (montant == null || montant <= 0) {
      return (rows: null, reason: EcheanceGenResult.missingLoyer);
    }

    // Calcule la durée en mois.
    int? dureeMois;
    if (row['date_fin_bail'] != null) {
      final fin = DateTime.parse(row['date_fin_bail'] as String);
      // Nombre de mois entre début et fin (inclus les deux bornes).
      dureeMois =
          (fin.year - startDate.year) * 12 + (fin.month - startDate.month);
    } else if (row['duree_bail_mois'] != null) {
      dureeMois = row['duree_bail_mois'] as int;
    }
    if (dureeMois == null || dureeMois <= 0) {
      return (rows: null, reason: EcheanceGenResult.missingDuree);
    }

    final proprietaireId = row['proprietaire_id'] as String?;
    if (proprietaireId == null) {
      return (rows: null, reason: EcheanceGenResult.edlNotFound);
    }

    final rows = <Map<String, dynamic>>[];

    // Échéance du dépôt de garantie (caution) = loyer × nb de mois de dépôt,
    // exigée au début du bail. À recevoir (propriétaire) = à payer (locataire).
    final depotMois = await _depotGarantieMois(
      chambreId: row['chambre_id'] as int?,
      immeubleId: row['immeuble_id'] as int?,
    );
    if (depotMois != null && depotMois > 0) {
      rows.add({
        'owner_id': proprietaireId,
        'locataire_id': row['locataire_id'],
        'etat_de_lieux_id': edlId,
        'immeuble_id': row['immeuble_id'],
        'chambre_id': row['chambre_id'],
        'montant': montant * depotMois,
        'date_echeance':
            '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-01',
        'statut': 'a_recevoir',
        'notes': 'Dépôt de garantie (caution)',
      });
    }

    for (var i = 0; i < dureeMois; i++) {
      final echeance =
          DateTime(startDate.year, startDate.month + i, 1);
      rows.add({
        'owner_id': proprietaireId,
        'locataire_id': row['locataire_id'],
        'etat_de_lieux_id': edlId,
        'immeuble_id': row['immeuble_id'],
        'chambre_id': row['chambre_id'],
        'montant': montant,
        'date_echeance':
            '${echeance.year}-${echeance.month.toString().padLeft(2, '0')}-01',
        'statut': 'a_recevoir',
      });
    }

    return (rows: rows, reason: null);
  }

  /// Loyer mensuel de la chambre (bail individuel) ou, à défaut, de l'immeuble
  /// (bail location). Utilisé pour générer les échéances quand la colonne
  /// `montant` de l'EDL n'est pas renseignée.
  static Future<double?> _loyerMensuel({
    int? chambreId,
    int? immeubleId,
  }) async {
    if (chambreId != null) {
      final c = await _db
          .from('Chambres')
          .select('prix_loyer')
          .eq('id', chambreId)
          .maybeSingle();
      final v = (c?['prix_loyer'] as num?)?.toDouble();
      if (v != null && v > 0) return v;
    }
    if (immeubleId != null) {
      final i = await _db
          .from('Immeubles')
          .select('prix_loyer')
          .eq('id', immeubleId)
          .maybeSingle();
      return (i?['prix_loyer'] as num?)?.toDouble();
    }
    return null;
  }

  /// Nombre de mois de dépôt de garantie de la chambre (sinon de l'immeuble).
  static Future<double?> _depotGarantieMois({
    int? chambreId,
    int? immeubleId,
  }) async {
    if (chambreId != null) {
      final c = await _db
          .from('Chambres')
          .select('depot_garantie_mois')
          .eq('id', chambreId)
          .maybeSingle();
      final v = (c?['depot_garantie_mois'] as num?)?.toDouble();
      if (v != null && v > 0) return v;
    }
    if (immeubleId != null) {
      final i = await _db
          .from('Immeubles')
          .select('depot_garantie_mois')
          .eq('id', immeubleId)
          .maybeSingle();
      return (i?['depot_garantie_mois'] as num?)?.toDouble();
    }
    return null;
  }

  // ── Sortie précoce : suppression des échéances futures ───────────────────

  /// Supprime toutes les échéances de l'EDL d'entrée [entreeEdlId] dont la
  /// date est ≥ au 1er du mois **suivant** [departureDate].
  ///
  /// Règle par défaut : le locataire paie le mois entier en cours (pas de
  /// prorata). Exemple : départ le 15 juin → juin payé, juillet et au-delà
  /// supprimés. Si [proRata] est vrai, l'échéance du mois de départ est
  /// **réduite** au prorata des jours occupés (au lieu de rester au montant
  /// plein) — le montant de référence est recalculé depuis le loyer de la
  /// chambre/immeuble (pas depuis la ligne existante), pour rester idempotent
  /// même si la résiliation est annulée puis rejouée.
  static Future<void> deleteFutureInstallments(
    int entreeEdlId,
    DateTime departureDate, {
    bool proRata = false,
  }) async {
    final monthStart = DateTime(departureDate.year, departureDate.month, 1);
    final nextMonth =
        DateTime(departureDate.year, departureDate.month + 1, 1);
    final cutoff =
        '${nextMonth.year}-${nextMonth.month.toString().padLeft(2, '0')}-01';
    await _db
        .from(_table)
        .delete()
        .eq('etat_de_lieux_id', entreeEdlId)
        .gte('date_echeance', cutoff);

    if (proRata) {
      final daysInMonth = nextMonth.difference(monthStart).inDays;
      final daysOccupied = departureDate.difference(monthStart).inDays + 1;
      final ratio = (daysOccupied / daysInMonth).clamp(0.0, 1.0);
      final edl = await _db
          .from('etat_de_lieux')
          .select('chambre_id, immeuble_id')
          .eq('id', entreeEdlId)
          .maybeSingle();
      final loyerPlein = await _loyerMensuel(
        chambreId: edl?['chambre_id'] as int?,
        immeubleId: edl?['immeuble_id'] as int?,
      );
      if (loyerPlein != null && loyerPlein > 0) {
        final monthKey =
            '${monthStart.year}-${monthStart.month.toString().padLeft(2, '0')}-01';
        await _db
            .from(_table)
            .update({'montant': loyerPlein * ratio})
            .eq('etat_de_lieux_id', entreeEdlId)
            .eq('date_echeance', monthKey)
            .isFilter('notes', null)
            .neq('statut', 'recu');
      }
    }
    _invalidate();
  }

  // ── Écriture ─────────────────────────────────────────────────────────────

  /// Marque une recette comme reçue (paiement enregistré).
  static Future<void> markPaid(int id, DateTime datePaiement) async {
    final row = await _db
        .from(_table)
        .update({
          'statut': 'recu',
          'date_paiement': datePaiement.toIso8601String().substring(0, 10),
        })
        .eq('id', id)
        .select('etat_de_lieux_id')
        .maybeSingle();
    _invalidate();
    // Décompte de vétusté payé : la demande « à recevoir » est satisfaite.
    final edlId = row?['etat_de_lieux_id'] as int?;
    if (edlId != null) {
      await NotificationsDatasource.markReadForEdl(
        edlId,
        types: const ['vetuste_a_recevoir'],
      );
    }
  }

  /// Annule le marquage « reçu » (remet à « a_recevoir »).
  static Future<void> markUnpaid(int id) async {
    await _db.from(_table).update({
      'statut': 'a_recevoir',
      'date_paiement': null,
    }).eq('id', id);
    _invalidate();
  }

  /// Marque une recette comme en retard.
  static Future<void> markLate(int id) async {
    await _db.from(_table).update({'statut': 'en_retard'}).eq('id', id);
    _invalidate();
  }

  /// Ajoute une recette manuelle (non liée à un bail). [sens] = 'recevoir'
  /// (argent dû au propriétaire, défaut) ou 'payer' (ex. remboursement de
  /// caution — argent dû par le propriétaire, vu comme « à recevoir » côté
  /// locataire).
  static Future<void> createManual({
    required String ownerId,
    required int? immeubleId,
    int? chambreId,
    String? locataireId,
    int? edlId,
    required double montant,
    required DateTime dateEcheance,
    String? notes,
    String sens = 'recevoir',
  }) async {
    await _db.from(_table).insert({
      'owner_id': ownerId,
      'locataire_id': locataireId,
      'etat_de_lieux_id': edlId,
      'immeuble_id': immeubleId,
      'chambre_id': chambreId,
      'montant': montant,
      'date_echeance': dateEcheance.toIso8601String().substring(0, 10),
      'statut': 'a_recevoir',
      'sens': sens,
      'notes': notes,
    });
    _invalidate();
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }
}
