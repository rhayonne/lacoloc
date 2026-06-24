import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lacoloc_front/config/env_config.dart';
import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/datasources/recettes.dart';
import 'package:lacoloc_front/data/datasources/signatures.dart';
import 'package:lacoloc_front/data/datasources/session_scope.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      final rows =
          await filtered.order('date_etat_lieux', ascending: false);
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
        final estCollectifIndividuel =
            edl.partie == PartieEdl.commune && edl.typeBail == 'individuel';
        if (estCollectifIndividuel) continue;
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
        .order('created_at')
        .limit(1)
        .maybeSingle();
    return row == null ? null : EtatDesLieuxModel.fromMap(row);
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

  /// Met à jour la préférence de fenêtre « avenant / additions » du propriétaire.
  static Future<void> setAvenantWindowDays(int days) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db
        .from('Users_Client')
        .update({'avenant_window_days': days}).eq('id', uid);
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
    // Copie la signature dans l'espace de l'EDL (lisible par les deux parties).
    if (proprietaireSignatureUrl != null) {
      proprietaireSignatureUrl = await SignaturesDatasource.materializeForEdl(
        edlId: id,
        role: 'proprietaire',
        sourceRef: proprietaireSignatureUrl,
      );
    }
    // Snapshot de la fenêtre avenant/additions depuis la préférence du
    // propriétaire (Vision générale) — fixée à la finalisation pour rester
    // stable même si la préférence change ensuite.
    final windowDays = await getAvenantWindowDays();
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

    if (typeEdl == 'entree') {
      // Génère les échéances mensuelles (idempotent — ignoré si déjà créées).
      await RecettesDatasource.generateFromBail(id);
    } else if (typeEdl == 'sortie') {
      // Supprime les échéances futures de l'entrée couplée : le locataire
      // paye le mois entier du départ, mais pas les mois suivants.
      final sortieRow = await _db
          .from(_table)
          .select('edl_entree_id, date_etat_lieux')
          .eq('id', id)
          .maybeSingle();
      if (sortieRow != null && sortieRow['edl_entree_id'] != null) {
        final entreeId = sortieRow['edl_entree_id'] as int;
        final departureDate =
            DateTime.parse(sortieRow['date_etat_lieux'] as String);
        await RecettesDatasource.deleteFutureInstallments(
            entreeId, departureDate);
      }
    }

    // Prévient le(s) locataire(s) qu'un état des lieux est à signer :
    // notification in-app/realtime + e-mail (best-effort, n'interrompt pas).
    await NotificationsDatasource.notifyEdlLocataire(
      edlId: id,
      type: 'edl_a_signer',
      title: 'État des lieux à signer',
      body: "Un état des lieux finalisé attend votre signature.",
    );
    await notifyASigner(edlId: id);
    invalidate();
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
    await _db.from(_table).update({
      'last_signature_request_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    await NotificationsDatasource.notifyEdlLocataire(
      edlId: id,
      type: 'edl_a_signer',
      title: 'Signature requise — état des lieux',
      body: "Votre bailleur vous demande de signer votre état des lieux en "
          "urgence. Merci de l'accepter et le signer dès que possible.",
    );
    await notifyASigner(edlId: id);
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
    await _db.from(_table).update({
      'last_signature_request_at': DateTime.now().toIso8601String(),
    }).eq('id', id);

    await NotificationsDatasource.notifyEdlLocataire(
      edlId: id,
      type: 'bail_remplissage',
      title: 'Documents requis pour votre bail',
      body: body ??
          "Votre bailleur vous demande de compléter les documents manquants "
              "de votre bail (garant et/ou signature).",
    );
    await notifyASigner(edlId: id);
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
  }) async {
    final now = DateTime.now();
    final today = now.toIso8601String().substring(0, 10);
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
    invalidate();
  }

  /// Enregistre le choix du propriétaire « ce bail nécessite-t-il un garant ? »
  /// sur l'EDL [id] (true = requis, false = sans garant).
  static Future<void> setBailAvecGarant(int id, bool value) async {
    await _db
        .from(_table)
        .update({'bail_avec_garant': value}).eq('id', id);
    invalidate();
  }

  /// Appose la signature du [role] (`proprietaire` ou `locataire`) sur le
  /// bail/EDL [id] : matérialise l'image dans l'espace de l'EDL (lisible par les
  /// deux parties via `can_access_edl`) puis enregistre l'URL + l'horodatage.
  /// Utilisé par le flux « signer le bail » (aperçu/impression du contrat de
  /// bail). Retourne l'URL matérialisée.
  static Future<String> setBailSignature({
    required int id,
    required String role,
    required String signatureUrl,
  }) async {
    final materialized = await SignaturesDatasource.materializeForEdl(
      edlId: id,
      role: role,
      sourceRef: signatureUrl,
    );
    final col = role == 'locataire' ? 'locataire' : 'proprietaire';
    await _db.from(_table).update({
      '${col}_signature_url': materialized,
      '${col}_signed_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
    invalidate();
    return materialized;
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
