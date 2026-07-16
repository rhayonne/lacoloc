import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lacoloc_front/config/env_config.dart';
import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
import 'package:lacoloc_front/data/datasources/garants.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/datasources/recettes.dart';
import 'package:lacoloc_front/data/datasources/signatures.dart';
import 'package:lacoloc_front/data/datasources/session_scope.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Résultat de l'acompte de caution en fin de bail ([EtatDesLieuxDatasource
/// ._settleCaution], appelé par [EtatDesLieuxDatasource.resilierBail]).
class CautionSettlement {
  final double? cautionMontant;
  final double deductions;
  final bool rembourse;
  final String? blockReason;

  const CautionSettlement({
    required this.cautionMontant,
    required this.deductions,
    required this.rembourse,
    this.blockReason,
  });
}

class EtatDesLieuxDatasource {
  EtatDesLieuxDatasource._();

  static final _db = Supabase.instance.client;
  static final _cache = DataCache.instance;

  /// Invalide tout le cache lié aux EDL (à appeler après un write d'EDL ou de
  /// ses tables filles : preneurs, observations, sections, relevés, clés).
  static void invalidate() => _cache.invalidatePrefix(CacheKeys.edl);

  /// URL de la page de création de mot de passe vers laquelle le lien
  /// d'invitation par e-mail doit rediriger. En prod (`EnvConfig.isProd`) on
  /// utilise `URL_EMAIL_CONFIRMATION_PROD`, sinon `URL_EMAIL_CONFIRMATION_DEV`.
  static String get _confirmationUrl {
    final key = EnvConfig.isProd
        ? 'URL_EMAIL_CONFIRMATION_PROD'
        : 'URL_EMAIL_CONFIRMATION_DEV';
    return dotenv.get(
      key,
      fallback: dotenv.get(
        'URL_EMAIL_CONFIRMATION',
        fallback: 'http://localhost:44785/confirmation-locataire',
      ),
    );
  }
  static const _table = 'etat_de_lieux';
  static const _select =
      '*, '
      'locataire:Users_Client!locataire_id(id, full_name, email, phone, created_at, invitation_email_sent, invitation_sent_at), '
      'immeuble:Immeubles!immeuble_id(id, name, address, location_meuble, type:Immeuble_Types_Reference!type_id(name)), '
      'chambre:Chambres!chambre_id(id, room_name), '
      'proprietaire:Users_Client!proprietaire_id(id, full_name, phone), '
      'preneurs:etat_de_lieux_preneurs(nom, locataire:Users_Client!locataire_id(full_name))';

  static Future<List<EtatDesLieuxModel>> listByProprietaire(
    String proprietaireId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.edl}prop:$proprietaireId', () async {
      // Multi-tenant : membro d'une entreprise → tous les EDL de l'entreprise.
      final entrepriseId = await SessionScope.currentEntrepriseId();
      final query = _db.from(_table).select(_select);
      final filtered = entrepriseId != null
          ? query.eq('entreprise_id', entrepriseId)
          : query.eq('proprietaire_id', proprietaireId);
      final rows = await filtered
          .eq('actif', true)
          .order('date_etat_lieux', ascending: false);
      return rows.map((r) => EtatDesLieuxModel.fromMap(r)).toList();
    }, refresh: refresh);
  }

  static Future<List<EtatDesLieuxModel>> listByLocataire(
    String locataireId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.edl}loc:$locataireId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('locataire_id', locataireId)
          .eq('actif', true)
          .order('date_etat_lieux', ascending: false);
      return rows.map((r) => EtatDesLieuxModel.fromMap(r)).toList();
    }, refresh: refresh);
  }

  /// EDLs onde o locataire é **preneur** (modelo collectif). Usa inner-join em
  /// `etat_de_lieux_preneurs` para filtrar. RLS: o preneur pode ler esses EDLs.
  static Future<List<EtatDesLieuxModel>> listByPreneur(
    String locataireId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.edl}preneur:$locataireId', () async {
      // Alias distinct (`pren_filter`) pour le inner-join de filtrage, afin de
      // ne pas entrer en collision avec l'embed `preneurs` de _select.
      final rows = await _db
          .from(_table)
          .select(
              '$_select, pren_filter:etat_de_lieux_preneurs!inner(locataire_id)')
          .eq('pren_filter.locataire_id', locataireId)
          .eq('actif', true)
          .order('date_etat_lieux', ascending: false);
      return rows.map((r) => EtatDesLieuxModel.fromMap(r)).toList();
    }, refresh: refresh);
  }

  /// EDLs visibles par le locataire dans SA liste :
  ///  • **bail individuel** → son EDL **privatif** (partie=privative, lié à sa
  ///    chambre). Le collectif (parties communes) n'apparaît PAS dans la liste —
  ///    le locataire le consulte depuis sa fiche privative (observations communes).
  ///  • **bail location** → l'EDL **commune** complet où il est preneur (il n'y a
  ///    pas de privatif dans ce cas).
  ///
  /// Concrètement : union de `listByLocataire` (privatifs) + `listByPreneur`
  /// (collectifs/communes), en **excluant** les collectifs d'un bail individuel
  /// (`partie==commune && type_bail=='individuel'`). Déduplicado por id.
  static Future<List<EtatDesLieuxModel>> listForLocataire(
    String locataireId,
  ) async {
    final results = await Future.wait([
      listByLocataire(locataireId),
      listByPreneur(locataireId),
    ]);
    final byId = <int, EtatDesLieuxModel>{};
    for (final list in results) {
      for (final edl in list) {
        // Cache le collectif d'un bail individuel : c'est juste le miroir des
        // privatifs ; le locataire voit son privatif, pas le collectif.
        if (edl.isCollectifInterne) continue;
        byId[edl.id] = edl;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.dateEtatLieux.compareTo(a.dateEtatLieux));
    return merged;
  }

  static Future<EtatDesLieuxModel> create(EtatDesLieuxModel m) async {
    final row = await _db
        .from(_table)
        .insert(m.toInsert())
        .select(_select)
        .single();
    invalidate();
    return EtatDesLieuxModel.fromMap(row);
  }

  static Future<EtatDesLieuxModel?> findById(int id) async {
    final row = await _db
        .from(_table)
        .select(_select)
        .eq('id', id)
        .maybeSingle();
    return row != null ? EtatDesLieuxModel.fromMap(row) : null;
  }

  /// EDL `partie = commune` (collectif) de um imóvel para um dado `type_edl`.
  /// Há no máximo um por imóvel + type_edl (entrée/sortie). Retorna null se ainda
  /// não existir.
  static Future<EtatDesLieuxModel?> findCollectif({
    required int immeubleId,
    required String typeEdl,
  }) async {
    final row = await _db
        .from(_table)
        .select(_select)
        .eq('immeuble_id', immeubleId)
        .eq('partie', 'commune')
        .eq('type_edl', typeEdl)
        .eq('actif', true)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return row == null ? null : EtatDesLieuxModel.fromMap(row);
  }

  /// Todos os EDLs collectif (partie=commune) de um imóvel, ordenados do mais
  /// recente ao mais antigo. Usado para o diálogo de seleção de ano letivo.
  static Future<List<EtatDesLieuxModel>> listAllCollectifs({
    required int immeubleId,
    required String typeEdl,
  }) async {
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('immeuble_id', immeubleId)
        .eq('partie', 'commune')
        .eq('type_edl', typeEdl)
        .eq('actif', true)
        .order('created_at', ascending: false);
    return rows.map((r) => EtatDesLieuxModel.fromMap(r)).toList();
  }

  /// EDL collectif **ouvert** (non finalisé) du `partie='commune'` d'un imóvel
  /// para um `type_edl`. Retorna null se não houver collectif aberto (ex.: o
  /// único existente já foi finalizado → caso avenant). Mais recente primeiro.
  static Future<EtatDesLieuxModel?> findOpenCollectif({
    required int immeubleId,
    required String typeEdl,
  }) async {
    final row = await _db
        .from(_table)
        .select(_select)
        .eq('immeuble_id', immeubleId)
        .eq('partie', 'commune')
        .eq('type_edl', typeEdl)
        .eq('actif', true)
        .neq('situation', 'finalise')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : EtatDesLieuxModel.fromMap(row);
  }

  /// Garante a existência de um EDL collectif **aberto** do imóvel e devolve seu
  /// id. Reusa o collectif aberto se houver; senão **cria um novo** (não reusa
  /// um collectif finalizado — esse caso passa pelo fluxo Avenant).
  static Future<int> ensureCollectif(EtatDesLieuxModel commune) async {
    final existing = await findOpenCollectif(
      immeubleId: commune.immeubleId,
      typeEdl: commune.typeEdl,
    );
    if (existing != null) return existing.id;
    final created = await create(commune);
    return created.id;
  }

  /// Marca um privatif como avenant (locataire entré após a finalização do
  /// collectif).
  static Future<void> markAvenant(int privatifId, DateTime date) async {
    await _db.from(_table).update({
      'is_avenant': true,
      'avenant_date': date.toIso8601String().substring(0, 10),
    }).eq('id', privatifId);
    invalidate();
  }

  /// Date du premier contrat signé d'un collectif : la plus ancienne
  /// `date_finalisation` parmi ses privatifs (à défaut, la plus ancienne
  /// `date_etat_lieux`). Null si aucun privatif.
  static Future<DateTime?> firstSignedContractDate(int collectifId) async {
    final privatifs = await listPrivativesByCollectif(collectifId);
    if (privatifs.isEmpty) return null;
    DateTime? best;
    for (final p in privatifs) {
      final d = p.dateFinalisation ?? p.dateEtatLieux;
      if (best == null || d.isBefore(best)) best = d;
    }
    return best;
  }

  /// EDL privatif d'une chambre pour un type_edl donné (entrée/sortie).
  /// Retourne null s'il n'existe pas encore.
  static Future<EtatDesLieuxModel?> findPrivatif({
    required int chambreId,
    required String typeEdl,
  }) async {
    final row = await _db
        .from(_table)
        .select(_select)
        .eq('chambre_id', chambreId)
        .eq('partie', 'privative')
        .eq('type_edl', typeEdl)
        .eq('actif', true)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return row == null ? null : EtatDesLieuxModel.fromMap(row);
  }

  /// EDL privatifs d'**entrée** d'un immeuble, indexés par `chambre_id`.
  /// Sert à afficher le statut détaillé (phase du processus) de chaque chambre.
  static Future<Map<int, EtatDesLieuxModel>> entreePrivatifsByImmeuble(
    int immeubleId,
  ) async {
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('immeuble_id', immeubleId)
        .eq('partie', 'privative')
        .eq('type_edl', 'entree')
        .eq('actif', true)
        .order('created_at');
    final map = <int, EtatDesLieuxModel>{};
    for (final r in rows) {
      final edl = EtatDesLieuxModel.fromMap(r);
      final cid = edl.chambreId;
      if (cid != null) map[cid] = edl; // le dernier (par date) prévaut
    }
    return map;
  }

  /// Garante a existência do EDL privatif da chambre (idempotente) e devolve-o.
  /// Evita duplicação em caso de double-clic / réentrance.
  static Future<EtatDesLieuxModel> ensurePrivatif(EtatDesLieuxModel privatif) async {
    final existing = await findPrivatif(
      chambreId: privatif.chambreId!,
      typeEdl: privatif.typeEdl,
    );
    if (existing != null) return existing;
    return create(privatif);
  }

  /// Ids des chambres d'un immeuble qui ont **déjà** un EDL privatif de ce
  /// [typeEdl] (`entree`/`sortie`). Sert à désactiver leur sélection lors de la
  /// création d'un nouvel EDL (pas de doublon d'entrée/sortie pour une chambre).
  static Future<Set<int>> chambreIdsWithEdl({
    required int immeubleId,
    required String typeEdl,
  }) async {
    final rows = await _db
        .from(_table)
        .select('chambre_id')
        .eq('immeuble_id', immeubleId)
        .eq('partie', 'privative')
        .eq('type_edl', typeEdl)
        .eq('actif', true)
        .not('chambre_id', 'is', null);
    return {
      for (final r in rows)
        if (r['chambre_id'] != null) r['chambre_id'] as int,
    };
  }

  /// Comme [chambreIdsWithEdl] mais pour plusieurs immeubles en une requête.
  /// (les ids de chambres étant uniques, un seul Set suffit pour tous.)
  static Future<Set<int>> chambreIdsWithEdlForImmeubles({
    required List<int> immeubleIds,
    required String typeEdl,
  }) async {
    if (immeubleIds.isEmpty) return {};
    final rows = await _db
        .from(_table)
        .select('chambre_id')
        .inFilter('immeuble_id', immeubleIds)
        .eq('partie', 'privative')
        .eq('type_edl', typeEdl)
        .eq('actif', true)
        .not('chambre_id', 'is', null);
    return {
      for (final r in rows)
        if (r['chambre_id'] != null) r['chambre_id'] as int,
    };
  }

  /// EDLs privatifs ligados a um EDL collectif (uma chambre cada).
  static Future<List<EtatDesLieuxModel>> listPrivativesByCollectif(
    int collectifId,
  ) async {
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('edl_collectif_id', collectifId)
        .eq('actif', true)
        .order('date_etat_lieux', ascending: false);
    return rows.map((r) => EtatDesLieuxModel.fromMap(r)).toList();
  }

  // ── EDL de sortie (couplé à une entrée finalisée) ───────────────────────────

  /// Le sortie déjà créé pour un EDL d'entrée donné (par `edl_entree_id`), ou
  /// null. Sert à l'idempotence de [createSortieFromEntree].
  static Future<EtatDesLieuxModel?> findSortieForEntree(int entreeId) async {
    final row = await _db
        .from(_table)
        .select(_select)
        .eq('edl_entree_id', entreeId)
        .eq('type_edl', 'sortie')
        .eq('actif', true)
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return row == null ? null : EtatDesLieuxModel.fromMap(row);
  }

  /// Entrées **finalisées** du proprietaire éligibles à un EDL de sortie, et qui
  /// n'ont pas encore de sortie : location (commune) + privatifs (individuel,
  /// une chambre). Triées par date décroissante.
  static Future<List<EtatDesLieuxModel>> listFinalizedEntreesForSortie(
    String proprietaireId,
  ) async {
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('proprietaire_id', proprietaireId)
        .eq('type_edl', 'entree')
        .eq('situation', 'finalise')
        .eq('actif', true)
        .order('date_etat_lieux', ascending: false);
    final entrees = rows.map((r) => EtatDesLieuxModel.fromMap(r)).toList();
    final candidates = entrees.where((e) =>
        (e.typeBail == 'location' && e.partie == PartieEdl.commune) ||
        e.partie == PartieEdl.privative).toList();
    // Exclure les entrées qui ont déjà un sortie.
    final sortieRows = await _db
        .from(_table)
        .select('edl_entree_id')
        .eq('proprietaire_id', proprietaireId)
        .eq('type_edl', 'sortie')
        .eq('actif', true)
        .not('edl_entree_id', 'is', null);
    final done = {
      for (final r in sortieRows)
        if (r['edl_entree_id'] != null) r['edl_entree_id'] as int,
    };
    return candidates.where((e) => !done.contains(e.id)).toList();
  }

  /// Crée (idempotent) l'EDL de sortie couplé à une entrée finalisée, en copiant
  /// la structure (sections + lignes), les preneurs et les relevés/clés depuis
  /// l'entrée. **N'altère jamais l'entrée.** Retourne le sortie principal
  /// (privatif pour un bail individuel, commune pour une location).
  static Future<EtatDesLieuxModel> createSortieFromEntree(
    EtatDesLieuxModel entree,
  ) async {
    final uid = entree.proprietaireId;
    final now = DateTime.now();
    final situation = SituationEdl.fromDate(now);

    // Bail location → un seul EDL sortie « commune ».
    if (entree.partie == PartieEdl.commune) {
      final existing = await findSortieForEntree(entree.id);
      if (existing != null) return existing;
      final sortie = await create(EtatDesLieuxModel(
        id: 0,
        proprietaireId: uid,
        immeubleId: entree.immeubleId,
        locataireId: entree.locataireId,
        typeBail: entree.typeBail,
        typeEdl: 'sortie',
        dateEtatLieux: now,
        situation: situation,
        createdAt: now,
        partie: PartieEdl.commune,
        edlEntreeId: entree.id,
      ));
      await EdlDetailsDatasource.copyStructure(entree.id, sortie.id);
      await EdlDetailsDatasource.copyPreneurs(entree.id, sortie.id);
      await EdlDetailsDatasource.copyReleves(entree.id, sortie.id);
      return sortie;
    }

    // Bail individuel : `entree` est un privatif.
    // 1) Sortie collectif (parties communes), lié au collectif d'entrée.
    int? sortieCollectifId;
    final entreeCollectifId = entree.edlCollectifId;
    if (entreeCollectifId != null) {
      final existingColl = await findSortieForEntree(entreeCollectifId);
      if (existingColl != null) {
        sortieCollectifId = existingColl.id;
      } else {
        final sortieColl = await create(EtatDesLieuxModel(
          id: 0,
          proprietaireId: uid,
          immeubleId: entree.immeubleId,
          typeBail: 'individuel',
          typeEdl: 'sortie',
          dateEtatLieux: now,
          situation: situation,
          createdAt: now,
          partie: PartieEdl.commune,
          edlEntreeId: entreeCollectifId,
        ));
        sortieCollectifId = sortieColl.id;
        await EdlDetailsDatasource.copyStructure(
            entreeCollectifId, sortieColl.id);
        await EdlDetailsDatasource.copyPreneurs(
            entreeCollectifId, sortieColl.id);
        await EdlDetailsDatasource.copyReleves(
            entreeCollectifId, sortieColl.id);
      }
    }

    // 2) Sortie privatif de la chambre.
    final existingPriv = await findSortieForEntree(entree.id);
    if (existingPriv != null) return existingPriv;
    final sortiePriv = await create(EtatDesLieuxModel(
      id: 0,
      proprietaireId: uid,
      immeubleId: entree.immeubleId,
      chambreId: entree.chambreId,
      locataireId: entree.locataireId,
      typeBail: 'individuel',
      typeEdl: 'sortie',
      dateEtatLieux: now,
      situation: situation,
      createdAt: now,
      partie: PartieEdl.privative,
      edlCollectifId: sortieCollectifId,
      edlEntreeId: entree.id,
    ));
    await EdlDetailsDatasource.copyStructure(entree.id, sortiePriv.id);
    await EdlDetailsDatasource.copyPreneurs(entree.id, sortiePriv.id);
    await EdlDetailsDatasource.copyCles(entree.id, sortiePriv.id);
    return sortiePriv;
  }

  static Future<EtatDesLieuxModel> update(
    int id,
    Map<String, dynamic> updates,
  ) async {
    final row = await _db
        .from(_table)
        .update(updates)
        .eq('id', id)
        .select(_select)
        .single();
    invalidate();
    return EtatDesLieuxModel.fromMap(row);
  }

  /// Finalise le privatif et enregistre les données du contrat de bail.
  /// Après la mise à jour de l'EDL et selon le sens :
  ///  • une **entrée** finalisée marque la chambre comme **occupée** ;
  ///  • une **sortie** finalisée **libère** la chambre (fin du contrat).
  /// Préférence du propriétaire connecté : durée (en jours) de la fenêtre
  /// « avenant / additions » ouverte après la finalisation d'un EDL.
  static Future<int> getAvenantWindowDays() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return kDefaultAvenantWindowDays;
    final row = await _db
        .from('Users_Client')
        .select('avenant_window_days')
        .eq('id', uid)
        .maybeSingle();
    return (row?['avenant_window_days'] as int?) ?? kDefaultAvenantWindowDays;
  }

  static Future<void> finaliser(
    int id, {
    DateTime? dateDebutBail,
    DateTime? dateFinBail,
    int? dureeBailMois,
    int? chambreId,
    String typeEdl = 'entree',
    String? proprietaireSignatureUrl,
  }) async {
    final now = DateTime.now();
    // Une fois signé par le propriétaire, cette signature est figée : on
    // refuse toute nouvelle tentative de (re)finaliser avec une signature —
    // même si l'UI n'affiche déjà plus le bouton dans ce cas.
    if (proprietaireSignatureUrl != null) {
      final existing = await _db
          .from(_table)
          .select('proprietaire_signed_at')
          .eq('id', id)
          .maybeSingle();
      if (existing?['proprietaire_signed_at'] != null) {
        throw Exception(
          'Cet état des lieux est déjà signé par le propriétaire : '
          'la signature ne peut plus être modifiée.',
        );
      }
    }
    // Copie la signature dans l'espace de l'EDL (lisible par les deux parties).
    if (proprietaireSignatureUrl != null) {
      proprietaireSignatureUrl = await SignaturesDatasource.materializeForEdl(
        edlId: id,
        role: 'proprietaire',
        sourceRef: proprietaireSignatureUrl,
      );
    }
    // Fenêtre avenant/additions : on **préserve le choix fait dans l'EDL**
    // (obligatoire avant finalisation) ; on ne retombe sur la préférence
    // globale que si l'EDL n'a rien (compat. anciens EDL).
    final edlRow = await _db
        .from(_table)
        .select('avenant_window_days')
        .eq('id', id)
        .maybeSingle();
    final windowDays = (edlRow?['avenant_window_days'] as int?) ??
        await getAvenantWindowDays();
    final updates = <String, dynamic>{
      'situation': SituationEdl.finalise.raw,
      'avenant_window_days': windowDays,
      if (dateDebutBail != null)
        'date_debut_bail': dateDebutBail.toIso8601String().substring(0, 10),
      if (dateFinBail != null)
        'date_fin_bail': dateFinBail.toIso8601String().substring(0, 10),
      'duree_bail_mois': ?dureeBailMois,
      'proprietaire_signed_at': now.toIso8601String(),
      'proprietaire_signature_url': ?proprietaireSignatureUrl,
    };
    await _db.from(_table).update(updates).eq('id', id);
    if (chambreId case final id?) {
      await ChambresDatasource.setOccupied(id, occupied: typeEdl != 'sortie');
    }

    // Note : les échéances (loyer + caution) « à recevoir / à payer » ne sont
    // PAS générées ici. Le bail n'est « signé » qu'une fois **accepté par le
    // locataire** → la génération se fait dans `locataireAccepter`.
    //
    // Note : la finalisation d'un EDL de **sortie** ne coupe PAS les échéances
    // futures ici — le bail ne peut être résilié qu'après que le locataire a
    // accepté/signé ce sortie (voir [resilierBail]) ; c'est ce moment-là, pas
    // la finalisation côté propriétaire, qui déclenche la coupe des loyers.

    // Prévient le(s) locataire(s) qu'un état des lieux est à signer :
    // notification in-app/realtime + e-mail (best-effort, n'interrompt pas).
    await NotificationsDatasource.notifyEdlLocataire(
      edlId: id,
      type: 'edl_a_signer',
      title: 'État des lieux à signer',
      body: "Un état des lieux finalisé attend votre signature.",
    );
    await notifyASigner(edlId: id);
    // Journal d'audit de signature (le propriétaire valide/signe en finalisant).
    await recordSignatureAudit(edlId: id, documentType: 'edl', role: 'proprietaire');
    invalidate();
  }

  /// Enregistre une entrée d'audit de signature (faisceau d'indices) via l'Edge
  /// Function `record-signature-audit` : l'identité (compte), l'horodatage,
  /// l'IP/user-agent et l'empreinte du document sont consignés côté serveur de
  /// façon non falsifiable et immuable. Best-effort : n'interrompt jamais le
  /// flux de signature si l'enregistrement échoue.
  static Future<void> recordSignatureAudit({
    required int edlId,
    required String documentType, // 'edl' | 'bail'
    required String role, // 'proprietaire' | 'locataire'
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'record-signature-audit',
        body: {'edlId': edlId, 'documentType': documentType, 'role': role},
      );
    } catch (_) {
      // best-effort
    }
  }

  /// Le propriétaire (re)demande au locataire de signer un EDL finalisé non
  /// signé : notification in-app + e-mail. **Anti-spam : 1 demande / 5 jours**
  /// (vérifié sur `last_signature_request_at`). Lance une `Exception` si la
  /// dernière demande date de moins de 5 jours.
  static Future<void> requestSignature(int id) async {
    final row = await _db
        .from(_table)
        .select('last_signature_request_at')
        .eq('id', id)
        .maybeSingle();
    final lastRaw = row?['last_signature_request_at'] as String?;
    if (lastRaw != null) {
      final days = DateTime.now().difference(DateTime.parse(lastRaw)).inDays;
      if (days < 5) {
        throw Exception(
            'Une demande a déjà été envoyée il y a $days jour(s). '
            'Réessayez dans ${5 - days} jour(s).');
      }
    }
    // On notifie D'ABORD : si l'envoi échoue, on ne pose pas l'horodatage
    // anti-spam → le bouton « Demander signature » reste actif (l'utilisateur
    // peut réessayer) au lieu d'être bloqué 5 jours par une demande ratée.
    await NotificationsDatasource.notifyEdlLocataire(
      edlId: id,
      type: 'edl_a_signer',
      title: 'Signature requise — état des lieux',
      body: "Votre bailleur vous demande de signer votre état des lieux en "
          "urgence. Merci de l'accepter et le signer dès que possible.",
    );
    await notifyASigner(edlId: id);

    await _db.from(_table).update({
      'last_signature_request_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    invalidate();
  }

  /// Le propriétaire (re)demande au locataire de **compléter les documents
  /// manquants** du bail (garant / signature). Notification + e-mail.
  /// Anti-spam : 1 demande / 5 jours (réutilise `last_signature_request_at`).
  static Future<void> requestBailCompletion(int id, {String? body}) async {
    final row = await _db
        .from(_table)
        .select('last_signature_request_at')
        .eq('id', id)
        .maybeSingle();
    final lastRaw = row?['last_signature_request_at'] as String?;
    if (lastRaw != null) {
      final days = DateTime.now().difference(DateTime.parse(lastRaw)).inDays;
      if (days < 5) {
        throw Exception(
            'Une demande a déjà été envoyée il y a $days jour(s). '
            'Réessayez dans ${5 - days} jour(s).');
      }
    }
    // Notifier d'abord (cf. requestSignature) : pas d'horodatage si l'envoi rate.
    await NotificationsDatasource.notifyEdlLocataire(
      edlId: id,
      type: 'bail_remplissage',
      title: 'Documents requis pour votre bail',
      body: body ??
          "Votre bailleur vous demande de compléter les documents manquants "
              "de votre bail (garant et/ou signature).",
    );
    await notifyASigner(edlId: id);

    await _db.from(_table).update({
      'last_signature_request_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    invalidate();
  }

  static Future<void> delete(int id) async {
    final row = await _db
        .from(_table)
        .select('edl_collectif_id, locataire_id, partie, situation')
        .eq('id', id)
        .maybeSingle();
    if (row != null) {
      // Règle : un EDL finalisé ne peut pas être supprimé.
      if (row['situation'] == 'finalise') {
        throw Exception(
            'Cet état des lieux est finalisé et ne peut pas être supprimé.');
      }
      // Règle : un collectif lié à des EDL individuels ne peut être supprimé
      // qu'après suppression de tous ses privatifs.
      if (row['partie'] == 'commune') {
        final privatifs =
            await _db.from(_table).select('id').eq('edl_collectif_id', id);
        if ((privatifs as List).isNotEmpty) {
          throw Exception(
              'Ce contrat collectif est lié à des états des lieux individuels. '
              'Supprimez-les d\'abord.');
        }
      }
      // Privatif lié à un collectif : retirer aussi le preneur correspondant
      // du collectif (le locataire quitte le contrat).
      if (row['partie'] == 'privative' &&
          row['edl_collectif_id'] != null &&
          row['locataire_id'] != null) {
        await EdlDetailsDatasource.deletePreneurByLocataire(
          row['edl_collectif_id'] as int,
          row['locataire_id'] as String,
        );
      }
    }
    await _db.from(_table).delete().eq('id', id);
    // Le collectif orphelin (bail individuel, dernier privatif supprimé) est
    // supprimé ATOMIQUEMENT côté DB par le trigger `trg_delete_orphan_collectif`
    // (migration 20260715000035) — jamais un finalisé. Rien à faire ici.
    invalidate();
  }

  // ─────────────────────── Super admin : gestion globale ─────────────────────

  /// Tous les EDL du système (super admin) — **inclut les inactifs**. Filtre
  /// texte optionnel sur code / locataire / proprietaire / immeuble / chambre.
  /// RLS : réservé au super admin (is_super_admin voit tout).
  static Future<List<EtatDesLieuxModel>> listAllForAdmin({
    String query = '',
  }) async {
    final rows =
        await _db.from(_table).select(_select).order('date_etat_lieux',
            ascending: false);
    var list = rows.map((r) => EtatDesLieuxModel.fromMap(r)).toList();
    if (query.trim().isNotEmpty) {
      list = list.where((e) => adminQueryMatches(e, query)).toList();
    }
    return list;
  }

  /// Filtre texte de la recherche admin (code / locataire / proprietaire /
  /// immeuble / chambre / preneurs). Exposé pour filtrer **en mémoire** côté
  /// UI (la liste est téléchargée une fois, pas à chaque frappe).
  static bool adminQueryMatches(EtatDesLieuxModel e, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    bool has(String? s) => (s ?? '').toLowerCase().contains(q);
    return has(e.code) ||
        has(e.locataireNom) ||
        has(e.locataireEmail) ||
        has(e.proprietaireNom) ||
        has(e.immeubleNom) ||
        has(e.chambreNom) ||
        e.preneursNoms.any((n) => n.toLowerCase().contains(q));
  }

  /// Active/désactive un EDL avec cascade (super admin) :
  ///  • **privatif** (individuel) → ce privatif + son/ses sortie(s). Le collectif
  ///    reste lié aux autres privatifs actifs (le collectif n'est pas touché).
  ///  • **collectif** (individuel) → tous ses privatifs + leurs sorties (retrait
  ///    de toute la colocation).
  ///  • **location** (commune) → cet EDL + son/ses sortie(s) (cascade complète).
  /// Libère (désactivation) ou ré-occupe (réactivation d'une entrée finalisée)
  /// la chambre concernée.
  static Future<void> setActive(int id, bool active) async {
    final self = await _db
        .from(_table)
        .select('id, partie, type_bail, type_edl, chambre_id, situation')
        .eq('id', id)
        .maybeSingle();
    if (self == null) return;

    final ids = <int>{id};
    // EDL « porteurs » de chambre concernés par la cascade (self + privatifs
    // d'un collectif) — sert à libérer/ré-occuper les chambres plus bas.
    final chambrePorteurs = <Map<String, dynamic>>[self];

    // Sorties couplées (edl_entree_id) — toujours en cascade avec leur entrée.
    Future<void> addSorties(int entreeId) async {
      final s =
          await _db.from(_table).select('id').eq('edl_entree_id', entreeId);
      for (final r in (s as List)) {
        ids.add(r['id'] as int);
      }
    }

    await addSorties(id);

    // Collectif d'une colocation → tous les privatifs + leurs sorties.
    if (self['partie'] == 'commune' && self['type_bail'] == 'individuel') {
      final privs = await _db
          .from(_table)
          .select('id, chambre_id, type_edl, situation')
          .eq('edl_collectif_id', id);
      for (final r in (privs as List)) {
        final pid = r['id'] as int;
        ids.add(pid);
        chambrePorteurs.add(r as Map<String, dynamic>);
        await addSorties(pid);
      }
    }

    await _db
        .from(_table)
        .update({'actif': active}).inFilter('id', ids.toList());

    // Statut des chambres : libérées si désactivation ; ré-occupées si on
    // réactive une entrée finalisée. Couvre la chambre de l'EDL lui-même ET
    // celles des privatifs d'un collectif désactivé en cascade.
    for (final row in chambrePorteurs) {
      final chambreId = row['chambre_id'] as int?;
      if (chambreId == null) continue;
      if (!active) {
        await _db
            .from('Chambres')
            .update({'est_loue': false}).eq('id', chambreId);
      } else if (row['type_edl'] == 'entree' &&
          row['situation'] == 'finalise') {
        await _db
            .from('Chambres')
            .update({'est_loue': true}).eq('id', chambreId);
      }
    }
    invalidate();
  }

  /// Suppression **définitive** (super admin) — ignore les garde-fous de
  /// [delete] (finalisé / collectif lié). Pour un collectif, supprime d'abord
  /// ses privatifs. Les tables filles partent en cascade (ON DELETE CASCADE).
  static Future<void> deleteHardAdmin(int id) async {
    final row =
        await _db.from(_table).select('partie').eq('id', id).maybeSingle();
    if (row != null && row['partie'] == 'commune') {
      await _db.from(_table).delete().eq('edl_collectif_id', id);
    }
    await _db.from(_table).delete().eq('id', id);
    invalidate();
  }

  /// Collectifs **finalisés** dont l'immeuble a encore des chambres libres
  /// (sans privatif lié au collectif) — éligibles à un **avenant**. Pour chacun,
  /// renvoie le collectif, les chambres libres et la date du 1er contrat signé.
  /// Retorna os contratos que podem receber um avenant :
  /// — bail individuel : ao menos 1 privatif finalisé + ≥1 chambre sem privatif.
  /// — bail location : EDL commune finalisé + ≥1 chambre ativa !estLoue.
  /// O collectif (individuel) não precisa estar finalisé — o privatif qualifica.
  static Future<List<AmendableCollectif>> listAmendableCollectifs(
    String proprietaireId, {
    String typeEdl = 'entree',
  }) async {
    final all = await listByProprietaire(proprietaireId, refresh: true);
    final out = <AmendableCollectif>[];

    // ── Bail individuel : privatifs finalisés, dédupliqués par collectif ──────
    final finalisedPrivatifs = all.where((e) =>
        e.partie == PartieEdl.privative &&
        e.typeBail == 'individuel' &&
        e.typeEdl == typeEdl &&
        e.situation == SituationEdl.finalise);

    final seen = <int>{};
    for (final p in finalisedPrivatifs) {
      final collectifId = p.edlCollectifId;
      if (collectifId == null || seen.contains(collectifId)) continue;
      seen.add(collectifId);

      final collectif = all.where((e) => e.id == collectifId).firstOrNull;
      if (collectif == null) continue;

      final chambres =
          await ChambresDatasource.listByImmeuble(collectif.immeubleId);
      final allPrivatifs = await listPrivativesByCollectif(collectifId);
      final usedChambreIds =
          allPrivatifs.map((p) => p.chambreId).whereType<int>().toSet();
      final free = chambres
          .where((ch) => ch.isActive && !usedChambreIds.contains(ch.id))
          .toList();
      if (free.isEmpty) continue;

      out.add(AmendableCollectif(
        collectif: collectif,
        privatifs: allPrivatifs,
        freeChambres: free,
        firstSignedDate: await firstSignedContractDate(collectifId),
      ));
    }

    // ── Bail location : tout EDL commune finalisé est éligible (le bien entier
    // est loué en un seul contrat, pas de suivi par chambre individuelle).
    final finalisedLocation = all.where((e) =>
        e.partie == PartieEdl.commune &&
        e.typeBail == 'location' &&
        e.typeEdl == typeEdl &&
        e.situation == SituationEdl.finalise);

    for (final c in finalisedLocation) {
      out.add(AmendableCollectif(
        collectif: c,
        privatifs: const [],
        freeChambres: const [],
        firstSignedDate: c.dateFinalisation,
      ));
    }

    return out;
  }

  static Future<void> locataireAccepter(
    int id, {
    String? locataireSignatureUrl,
    String? locataireNom,
    String? lieuLabel,
  }) async {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
    // Une fois signé par le locataire, cette signature est figée : on refuse
    // toute nouvelle tentative d'acceptation avec une signature — même si
    // l'UI n'affiche déjà plus le bouton dans ce cas.
    if (locataireSignatureUrl != null) {
      final existing = await _db
          .from(_table)
          .select('locataire_signed_at')
          .eq('id', id)
          .maybeSingle();
      if (existing?['locataire_signed_at'] != null) {
        throw Exception(
          'Cet état des lieux est déjà signé par le locataire : '
          'la signature ne peut plus être modifiée.',
        );
      }
    }
    // Copie la signature dans l'espace de l'EDL (lisible par les deux parties).
    if (locataireSignatureUrl != null) {
      locataireSignatureUrl = await SignaturesDatasource.materializeForEdl(
        edlId: id,
        role: 'locataire',
        sourceRef: locataireSignatureUrl,
      );
    }
    await _db.from(_table).update({
      'locataire_accepte': true,
      'date_finalisation': today,
      'locataire_signed_at': now.toIso8601String(),
      'locataire_signature_url': ?locataireSignatureUrl,
    }).eq('id', id);
    // Journal d'audit : best-effort — un échec d'audit ne doit pas faire
    // croire que l'acceptation/signature a échoué (elle est déjà enregistrée).
    try {
      await recordSignatureAudit(
          edlId: id, documentType: 'edl', role: 'locataire');
    } catch (_) {}
    // NB : les échéances (loyer + caution) ne sont PAS générées ici. L'EDL et
    // le bail sont deux documents distincts → la génération se fait à la
    // signature **du bail** (`setBailSignature`), une fois les deux parties
    // signataires.
    // Le locataire vient de signer : ses rappels « à signer » n'ont plus lieu
    // d'être → on les marque lus pour qu'ils disparaissent des Messages/badges.
    await NotificationsDatasource.markReadForEdl(id, types: const ['edl_a_signer']);
    // Prévient le propriétaire que l'EDL (et donc le bail, qui réutilise la même
    // signature) a été accepté/signé — in-app + e-mail. Centralisé ici pour que
    // la notification parte **quel que soit** le chemin d'UI (best-effort).
    final lieu = (lieuLabel != null && lieuLabel.isNotEmpty) ? ' de $lieuLabel' : '';
    await NotificationsDatasource.notifyEdlProprietaire(
      edlId: id,
      type: 'edl_accepte',
      title: 'État des lieux accepté',
      body: '${locataireNom ?? 'Le locataire'} a accepté et signé '
          "l'état des lieux$lieu.",
    );
    await notifyAccepte(edlId: id, locataireNom: locataireNom);
    invalidate();
  }

  /// Vérifie que la signature du locataire est bien posée sur l'EDL [id] :
  /// `locataire_accepte = true` **et** une `locataire_signature_url` présente.
  /// Sert à confirmer côté UI que la signature a réellement été enregistrée.
  static Future<bool> isLocataireSigned(int id) async {
    final row = await _db
        .from(_table)
        .select('locataire_accepte, locataire_signature_url')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return false;
    final accepte = row['locataire_accepte'] == true;
    final url = row['locataire_signature_url'];
    return accepte && url != null && '$url'.isNotEmpty;
  }

  /// Enregistre le choix du propriétaire « ce bail nécessite-t-il un garant ? »
  /// sur l'EDL [id] (true = requis, false = sans garant).
  static Future<void> setBailAvecGarant(int id, bool value) async {
    await _db
        .from(_table)
        .update({'bail_avec_garant': value}).eq('id', id);
    invalidate();
  }

  /// Configure le préavis (mois) du bail. `null` = revient au défaut légal
  /// (1 mois meublé / 3 vide). Posé par le propriétaire dans « Configuration bail ».
  static Future<void> setBailPreavis(int id, int? mois) async {
    await _db.from(_table).update({'preavis_mois': mois}).eq('id', id);
    invalidate();
  }

  /// Résilie le bail (côté propriétaire) : enregistre le congé + le préavis,
  /// calcule la **fin effective** (= congé + préavis) et **rogne les échéances
  /// de loyer** au-delà (le locataire paye jusqu'au terme du préavis, mois
  /// entier ou prorata selon [proRata]).
  ///
  /// **Préalable obligatoire** : un état des lieux de **sortie** lié à cette
  /// entrée doit exister, être finalisé (propriétaire) ET accepté/signé par
  /// le locataire — le bail ne peut être rompu qu'une fois le départ constaté
  /// et validé des deux côtés (voir [sortieReadyForResiliation]).
  static Future<CautionSettlement> resilierBail(
    int id, {
    required DateTime congeDate,
    required int preavisMois,
    String? motif,
    bool proRata = false,
  }) async {
    final ready = await sortieReadyForResiliation(id);
    if (!ready) {
      throw Exception(
        "Un état des lieux de sortie finalisé et signé par le locataire "
        'est requis avant de résilier le bail.',
      );
    }
    final fin = EtatDesLieuxModel.finPreavis(congeDate, preavisMois);
    await _db.from(_table).update({
      'preavis_mois': preavisMois,
      'bail_conge_date': congeDate.toIso8601String().substring(0, 10),
      'bail_fin_effective': fin.toIso8601String().substring(0, 10),
      'bail_resilie_motif':
          (motif != null && motif.trim().isNotEmpty) ? motif.trim() : null,
      'bail_resilie_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    // Le locataire ne doit plus les loyers au-delà du préavis.
    await RecettesDatasource.deleteFutureInstallments(id, fin, proRata: proRata);
    invalidate();
    CautionSettlement settlement;
    try {
      settlement = await _settleCaution(id);
    } catch (_) {
      settlement = const CautionSettlement(
        cautionMontant: null,
        deductions: 0,
        rembourse: false,
        blockReason: 'Erreur lors du calcul — à régler manuellement.',
      );
    }
    return settlement;
  }

  /// Acompte la caution en fin de bail : si le locataire n'a **ni avenant**,
  /// **ni décompte de vétusté** à sa charge, **ni facture « En litige »**
  /// liée à la chambre, la caution payée à l'entrée est intégralement
  /// remboursée — une seule ligne `Recettes` (sens='payer') sert à la fois de
  /// « à payer » pour le propriétaire et de « à recevoir » pour le locataire.
  /// Sinon, rien n'est généré automatiquement : à régler manuellement.
  static Future<CautionSettlement> _settleCaution(int entreeId) async {
    final entree = await _db
        .from(_table)
        .select(
            'proprietaire_id, locataire_id, immeuble_id, chambre_id, is_avenant')
        .eq('id', entreeId)
        .maybeSingle();
    if (entree == null) {
      return const CautionSettlement(
          cautionMontant: null, deductions: 0, rembourse: false);
    }
    // Caution effectivement payée à l'entrée (sinon rien à rembourser).
    final cautionRow = await _db
        .from('Recettes')
        .select('id, montant, statut')
        .eq('etat_de_lieux_id', entreeId)
        .ilike('notes', 'Dépôt de garantie%')
        .maybeSingle();
    final cautionMontant = (cautionRow?['montant'] as num?)?.toDouble();
    if (cautionMontant == null || cautionRow?['statut'] != 'recu') {
      return CautionSettlement(
        cautionMontant: cautionMontant,
        deductions: 0,
        rembourse: false,
        blockReason: cautionMontant == null
            ? 'Aucune caution enregistrée pour ce bail — rien à rembourser.'
            : 'Caution non encore reçue — pas de remboursement à générer.',
      );
    }

    if (entree['is_avenant'] == true) {
      return CautionSettlement(
        cautionMontant: cautionMontant,
        deductions: 0,
        rembourse: false,
        blockReason:
            'Ce bail est un avenant (colocataire entré en cours de contrat) : '
            'la caution doit être réglée manuellement.',
      );
    }

    final sortie = await findSortieForEntree(entreeId);
    double vetusteTotal = 0;
    if (sortie != null) {
      final decomptes = await _db
          .from('vetuste_decompte')
          .select('total_montant')
          .eq('etat_de_lieux_id', sortie.id);
      for (final d in (decomptes as List)) {
        vetusteTotal += (d['total_montant'] as num?)?.toDouble() ?? 0;
      }
    }

    double litigeTotal = 0;
    final chambreId = entree['chambre_id'] as int?;
    if (chambreId != null) {
      final factures = await _db
          .from('Factures')
          .select('montant_ttc')
          .eq('chambre_id', chambreId)
          .eq('statut', 'En litige');
      for (final f in (factures as List)) {
        litigeTotal += (f['montant_ttc'] as num?)?.toDouble() ?? 0;
      }
    }

    final deductions = vetusteTotal + litigeTotal;
    if (deductions > 0) {
      return CautionSettlement(
        cautionMontant: cautionMontant,
        deductions: deductions,
        rembourse: false,
        blockReason:
            'Décompte de vétusté et/ou factures en litige à régler avant '
            'de rembourser la caution (total déductions : '
            '${deductions.toStringAsFixed(2)} €).',
      );
    }

    await RecettesDatasource.createManual(
      ownerId: entree['proprietaire_id'] as String,
      immeubleId: entree['immeuble_id'] as int?,
      chambreId: chambreId,
      locataireId: entree['locataire_id'] as String?,
      edlId: entreeId,
      montant: cautionMontant,
      dateEcheance: DateTime.now(),
      notes: 'Remboursement de la caution (fin de bail)',
      sens: 'payer',
    );
    return CautionSettlement(
      cautionMontant: cautionMontant,
      deductions: 0,
      rembourse: true,
    );
  }

  /// Le bail peut-il être résilié ? Exige un EDL de sortie lié à l'entrée
  /// [entreeId], finalisé par le propriétaire ET accepté/signé par le
  /// locataire (`locataire_accepte`).
  static Future<bool> sortieReadyForResiliation(int entreeId) async {
    final sortie = await findSortieForEntree(entreeId);
    if (sortie == null) return false;
    return sortie.situation == SituationEdl.finalise && sortie.locataireAccepte;
  }

  /// Annule la résiliation (efface le congé) et **restaure les échéances**
  /// rognées par `resilierBail` (réinsertion des seules manquantes —
  /// `regenerateMissingInstallments` — les payées/existantes sont intactes).
  static Future<void> annulerResiliation(int id) async {
    await _db.from(_table).update({
      'bail_conge_date': null,
      'bail_fin_effective': null,
      'bail_resilie_motif': null,
      'bail_resilie_at': null,
    }).eq('id', id);
    await RecettesDatasource.regenerateMissingInstallments(id);
    invalidate();
  }

  // ── Conditions obligatoires (readiness) : avenant, caution, garants ─────────

  /// Fenêtre d'avenant choisie **dans l'EDL** (obligatoire ; rien de
  /// présélectionné). `days` = 0 → « Sans avenant ».
  static Future<void> setEdlAvenantWindow(int id, int days) async {
    await _db
        .from(_table)
        .update({'avenant_window_days': days}).eq('id', id);
    invalidate();
  }

  /// Mode de règlement de la caution (choisi par le locataire) + détails
  /// éventuels (chèque : banque/numéro ; virement : IBAN ; etc.).
  static Future<void> setCaution(
    int id, {
    required String mode,
    Map<String, dynamic>? details,
  }) async {
    await _db.from(_table).update({
      'caution_mode': mode,
      'caution_details': details,
    }).eq('id', id);
    invalidate();
  }

  /// Ids des garants rattachés à l'EDL [edlId].
  static Future<List<int>> listGarantIdsForEdl(int edlId) async {
    final rows = await _db
        .from('etat_de_lieux_garants')
        .select('garant_id')
        .eq('etat_de_lieux_id', edlId);
    return (rows as List).map((r) => (r['garant_id'] as num).toInt()).toList();
  }

  /// Rattache un garant (actif du locataire) à l'EDL. Idempotent.
  static Future<void> linkGarant(int edlId, int garantId) async {
    await _db.from('etat_de_lieux_garants').upsert(
      {'etat_de_lieux_id': edlId, 'garant_id': garantId},
      onConflict: 'etat_de_lieux_id,garant_id',
      ignoreDuplicates: true,
    );
    invalidate();
  }

  /// Rattache PLUSIEURS garants à l'EDL en un seul upsert (évite le N+1
  /// « 1 upsert + 1 invalidation par garant »). Idempotent.
  static Future<void> linkGarants(int edlId, Iterable<int> garantIds) async {
    final rows = garantIds
        .toSet()
        .map((g) => {'etat_de_lieux_id': edlId, 'garant_id': g})
        .toList();
    if (rows.isEmpty) return;
    await _db.from('etat_de_lieux_garants').upsert(
          rows,
          onConflict: 'etat_de_lieux_id,garant_id',
          ignoreDuplicates: true,
        );
    invalidate();
  }

  /// Détache un garant de l'EDL.
  static Future<void> unlinkGarant(int edlId, int garantId) async {
    await _db
        .from('etat_de_lieux_garants')
        .delete()
        .eq('etat_de_lieux_id', edlId)
        .eq('garant_id', garantId);
    invalidate();
  }

  /// Automatisme (sans table de « demandes ») : quand le locataire ajoute /
  /// active un garant, on rattache automatiquement ses garants actifs aux
  /// **baux EN COURS D'ÉDITION** où il est preneur qui exigent un garant et
  /// n'en ont aucun. On **ne touche jamais** un EDL déjà finalisé/signé.
  ///
  /// À appeler après une création/activation de garant (page Garants).
  static Future<void> autoLinkGarantsForLocataire(String locataireId) async {
    // Garants actifs du locataire (rien à faire s'il n'en a aucun).
    final active = await GarantsDatasource.activeByLocataire(locataireId);
    if (active.isEmpty) return;

    // EDL d'entrée du locataire, « avec garant », NON finalisés (en édition).
    // Deux rattachements possibles : privatif individuel (`locataire_id`) OU
    // commune de bail location (le locataire n'y est que **preneur**,
    // `locataire_id` est null) — sans le second, l'automatisme ne couvrait
    // jamais les baux location.
    final preneurRows = await _db
        .from('etat_de_lieux_preneurs')
        .select('etat_de_lieux_id')
        .eq('locataire_id', locataireId);
    final preneurEdlIds = (preneurRows as List)
        .map((r) => (r['etat_de_lieux_id'] as num).toInt())
        .toSet();

    final orFilter = preneurEdlIds.isEmpty
        ? 'locataire_id.eq.$locataireId'
        : 'locataire_id.eq.$locataireId,id.in.(${preneurEdlIds.join(',')})';
    final rows = await _db
        .from(_table)
        .select('id')
        .or(orFilter)
        .eq('type_edl', 'entree')
        .eq('bail_avec_garant', true)
        .neq('situation', SituationEdl.finalise.raw);

    final edlIds =
        (rows as List).map((r) => (r['id'] as num).toInt()).toList();
    if (edlIds.isEmpty) return;

    // EDLs où un garant DE CE locataire est déjà rattaché (dans un bail
    // location, les garants des colocataires ne comptent pas) — UNE requête
    // pour tous les EDLs, en croisant avec les ids de garants du locataire.
    final locGarantIds = (await GarantsDatasource.listByLocataire(locataireId))
        .map((g) => g.id)
        .toList();
    final dejaServis = <int>{};
    if (locGarantIds.isNotEmpty) {
      final links = await _db
          .from('etat_de_lieux_garants')
          .select('etat_de_lieux_id')
          .inFilter('etat_de_lieux_id', edlIds)
          .inFilter('garant_id', locGarantIds);
      for (final l in (links as List)) {
        dejaServis.add((l['etat_de_lieux_id'] as num).toInt());
      }
    }

    // Un seul upsert groupé (edl × garant actif) pour tous les EDLs restants.
    final aInserer = <Map<String, dynamic>>[
      for (final edlId in edlIds)
        if (!dejaServis.contains(edlId))
          for (final g in active)
            {'etat_de_lieux_id': edlId, 'garant_id': g.id},
    ];
    if (aInserer.isEmpty) return;
    await _db.from('etat_de_lieux_garants').upsert(
          aInserer,
          onConflict: 'etat_de_lieux_id,garant_id',
          ignoreDuplicates: true,
        );
    invalidate();

    // Résout la relance in-app « garant requis » pour ces EDLs.
    for (final edlId in edlIds) {
      if (dejaServis.contains(edlId)) continue;
      try {
        await NotificationsDatasource.markReadForEdl(
          edlId,
          types: const ['bail_garant_requis'],
        );
      } catch (_) {}
    }
  }

  /// Appose la signature **du bail** du [role] (`proprietaire` ou `locataire`)
  /// sur l'EDL [id]. Le bail est un document DISTINCT de l'EDL : la signature
  /// est écrite dans les colonnes `bail_<role>_signature_url` (indépendantes de
  /// la signature de l'EDL). Matérialise l'image (`bail-<role>`) dans l'espace
  /// de l'EDL (lisible des deux parties via `can_access_edl`).
  ///
  /// Dès que **les deux parties** ont signé le bail, on génère les échéances
  /// (loyer + caution) « à recevoir / à payer » (`generateFromBail`, idempotent).
  /// Retourne l'URL matérialisée.
  static Future<String> setBailSignature({
    required int id,
    required String role,
    required String signatureUrl,
  }) async {
    final col = role == 'locataire' ? 'locataire' : 'proprietaire';
    // Une fois le bail signé par ce rôle, cette signature est figée : on
    // refuse toute nouvelle tentative de signature — même si l'UI n'affiche
    // déjà plus le bouton dans ce cas.
    final existing = await _db
        .from(_table)
        .select('bail_${col}_signed_at')
        .eq('id', id)
        .maybeSingle();
    if (existing?['bail_${col}_signed_at'] != null) {
      throw Exception(
        'Ce bail est déjà signé par ce rôle : '
        'la signature ne peut plus être modifiée.',
      );
    }
    final materialized = await SignaturesDatasource.materializeForEdl(
      edlId: id,
      role: 'bail-$role',
      sourceRef: signatureUrl,
    );
    await _db.from(_table).update({
      'bail_${col}_signature_url': materialized,
      'bail_${col}_signed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    // Journal d'audit : signature du bail par ce rôle.
    await recordSignatureAudit(edlId: id, documentType: 'bail', role: role);
    // Le bail vient d'être signé : on efface les rappels liés au bail
    // (garant/remplissage) ainsi que la notification « EDL accepté » du
    // destinataire courant (RLS-scopé) — la suite logique est traitée.
    await NotificationsDatasource.markReadForEdl(
      id,
      types: const ['bail_garant_requis', 'bail_remplissage', 'edl_accepte'],
    );
    // Bail signé par les DEUX parties → générer les échéances (à recevoir /
    // à payer). Best-effort + idempotent. ⚠️ L'INSERT dans `Recettes` n'est
    // autorisé (RLS `owner_all_recettes`) qu'au **propriétaire** : quand le
    // locataire signe en dernier, la génération est reprise côté proprietaire
    // à l'ouverture de l'EDL via [ensureBailEcheances].
    if (role == 'proprietaire') {
      await ensureBailEcheances(id);
    }
    invalidate();
    return materialized;
  }

  /// Génère (si absentes) les échéances loyer + caution d'un bail signé des
  /// deux parties. Idempotent, best-effort, **réservé au propriétaire** (la
  /// RLS de `Recettes` refuse l'INSERT aux autres rôles). À appeler à chaque
  /// ouverture proprietaire d'un EDL au bail complètement signé : couvre le
  /// cas où le locataire a signé en dernier (génération impossible sous sa
  /// session) ou où la génération a échoué (réseau).
  static Future<EcheanceGenResult> ensureBailEcheances(int id) async {
    final row = await _db
        .from(_table)
        .select('proprietaire_id, bail_locataire_signature_url, '
            'bail_proprietaire_signature_url')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return EcheanceGenResult.edlNotFound;
    final uid = _db.auth.currentUser?.id;
    if (uid == null || row['proprietaire_id'] != uid) {
      return EcheanceGenResult.notOwner;
    }
    if (row['bail_locataire_signature_url'] == null ||
        row['bail_proprietaire_signature_url'] == null) {
      return EcheanceGenResult.bailNotFullySigned;
    }
    try {
      return await RecettesDatasource.generateFromBail(id);
    } catch (_) {
      return EcheanceGenResult.missingLoyer;
    }
  }

  /// Notifie le propriétaire (e-mail) qu'un EDL a été accepté/signé.
  /// Best-effort. En dev, l'e-mail est livré dans `ADDR_MAIL_CONFIRMATION`.
  static Future<void> notifyAccepte({
    required int edlId,
    String? locataireNom,
  }) async {
    try {
      final mailTo = _devMailOverride;
      await Supabase.instance.client.functions.invoke(
        'notify-edl',
        body: {
          'edlId': edlId,
          'event': 'accepte',
          'locataireNom': ?locataireNom,
          'mailTo': ?mailTo,
        },
      );
    } catch (_) {
      // best-effort
    }
  }

  /// E-mail au(x) **locataire(s)** quand le propriétaire **finalise** l'EDL :
  /// il reste à le signer. Le(s) destinataire(s) sont résolus côté serveur à
  /// partir de l'EDL (privatif → locataire ; commune → preneurs). Best-effort.
  static Future<void> notifyASigner({required int edlId}) async {
    try {
      final mailTo = _devMailOverride;
      await Supabase.instance.client.functions.invoke(
        'notify-edl',
        body: {
          'edlId': edlId,
          'event': 'a_signer',
          'mailTo': ?mailTo,
        },
      );
    } catch (_) {
      // best-effort
    }
  }

  /// E-mail au propriétaire quand le **locataire** ajoute une addition après
  /// finalisation (comodo + texte de l'observation).
  static Future<void> notifyAddition({
    required int edlId,
    String? locataireNom,
    String? comodo,
    String? texte,
  }) async {
    try {
      final mailTo = _devMailOverride;
      await Supabase.instance.client.functions.invoke(
        'notify-edl',
        body: {
          'edlId': edlId,
          'event': 'addition',
          'locataireNom': ?locataireNom,
          'comodo': ?comodo,
          'texte': ?texte,
          'mailTo': ?mailTo,
        },
      );
    } catch (_) {
      // best-effort
    }
  }

  static Future<List<UsersClient>> searchLocataires(String query) async {
    final rows = await _db.rpc(
      'search_locataires',
      params: {'search_query': query.trim()},
    ) as List;
    return rows.map((r) => UsersClient.fromJson(r as Map<String, dynamic>)).toList();
  }

  static Future<bool> hasContratsLocataire(String locataireId) async {
    final res = await _db
        .from(_table)
        .select('id')
        .eq('locataire_id', locataireId)
        .limit(1);
    return (res as List).isNotEmpty;
  }

  static Future<bool> emailExists(String email) async {
    // Insensible à la casse (cohérent avec l'index unique users_client_email_unique_ci).
    final rows = await _db
        .from('Users_Client')
        .select('id')
        .ilike('email', email.trim())
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  static Future<bool> phoneExists(String phone) async {
    final row = await _db
        .from('Users_Client')
        .select('id')
        .eq('phone', phone)
        .maybeSingle();
    return row != null;
  }

  static Future<UsersClient?> getLocataireById(String id) async {
    final row = await _db
        .from('Users_Client')
        .select('id, full_name, email, phone, created_at')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return UsersClient.fromJson(row);
  }

  static Future<List<UsersClient>> listInvitedLocataires(
    String proprietaireId,
  ) async {
    final rows = await _db.rpc(
      'list_invited_locataires',
      params: {'p_proprietaire_id': proprietaireId},
    ) as List;
    return rows.map((r) => UsersClient.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// En **dev**, redirige tous les e-mails d'invitation vers `ADDR_MAIL_CONFIRMATION`
  /// (boîte de test), sans changer l'e-mail réel du compte créé. En prod : `null`.
  static String? get _devMailOverride {
    if (!EnvConfig.isDev) return null;
    final addr = dotenv.get('ADDR_MAIL_CONFIRMATION', fallback: '').trim();
    return addr.isEmpty ? null : addr;
  }

  /// Service de **test d'envoi d'e-mail** (réservé au super admin — la fonction
  /// edge vérifie le JWT). Envoie un e-mail de diagnostic du type demandé
  /// ([emailType] = `invite` pour création/activation, `reset` pour
  /// réinitialisation) à [to], **sans créer de compte**. Retourne la réponse
  /// complète de la fonction edge (objet affiché tel quel dans l'UI).
  static Future<Map<String, dynamic>> sendServiceTestEmail({
    required String to,
    String emailType = 'invite',
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'invite-locataire',
      body: {
        'test': true,
        'email': to,
        'emailType': emailType,
        'redirectTo': _confirmationUrl,
      },
    );
    final data = res.data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {'ok': false, 'error': 'Réponse inattendue : $data'};
  }

  static Future<String> inviteLocataire({
    required String fullName,
    required String email,
    required String proprietaireId,
    String? phone,
    DateTime? dateOfBirth,
  }) async {
    final mailTo = _devMailOverride;
    final res = await Supabase.instance.client.functions.invoke(
      'invite-locataire',
      body: {
        'fullName': fullName,
        'email': email,
        'proprietaireId': proprietaireId,
        'redirectTo': _confirmationUrl,
        'mailTo': ?mailTo,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (dateOfBirth != null)
          'dateOfBirth': dateOfBirth.toIso8601String().substring(0, 10),
      },
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
    return data['userId'] as String;
  }

  /// Renvoie l'invitation à un locataire déjà créé : la fonction edge génère
  /// une **nouvelle** mot de passe temporaire (valide) et réexpédie le lien
  /// d'activation. En dev, l'e-mail est livré dans `ADDR_MAIL_CONFIRMATION`.
  /// [fullName] est optionnel : la fonction edge le récupère en BD si absent.
  static Future<void> resendInvitation({
    required String userId,
    required String email,
    String? fullName,
  }) async {
    final mailTo = _devMailOverride;
    final res = await Supabase.instance.client.functions.invoke(
      'invite-locataire',
      body: {
        'resend': true,
        'userId': userId,
        'email': email,
        'redirectTo': _confirmationUrl,
        'mailTo': ?mailTo,
        if (fullName != null && fullName.isNotEmpty) 'fullName': fullName,
      },
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }

  /// Annule (supprime) l'invitation d'un locataire **pas encore activé** :
  /// supprime le compte via l'edge function (mode `del`). Réservé côté serveur
  /// au propriétaire émetteur / admin / super admin ; refuse un compte déjà
  /// activé ou lié à des contrats.
  static Future<void> cancelInvitation({required String userId}) async {
    final res = await Supabase.instance.client.functions.invoke(
      'invite-locataire',
      body: {'del': true, 'userId': userId},
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}

/// Résultat de [EtatDesLieuxDatasource.listAmendableCollectifs] : un collectif
/// finalisé qui peut encore recevoir un avenant.  [privatifs] = EDLs individuels
/// (partie=privative) existants dans ce contrat (pour afficher les locataires).
class AmendableCollectif {
  final EtatDesLieuxModel collectif;
  final List<EtatDesLieuxModel> privatifs;
  final List<ChambreModel> freeChambres;
  final DateTime? firstSignedDate;

  const AmendableCollectif({
    required this.collectif,
    required this.privatifs,
    required this.freeChambres,
    this.firstSignedDate,
  });
}
