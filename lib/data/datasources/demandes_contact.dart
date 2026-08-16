import 'package:habitafrance/data/cache/data_cache.dart';
import 'package:habitafrance/data/cache/realtime_service.dart';
import 'package:habitafrance/data/datasources/messages.dart';
import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DemandesContactDatasource {
  DemandesContactDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Demandes_Contact';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.demandes);

  /// Cria uma nova demanda de contato pelo locataire autenticado.
  ///
  /// Notifica o proprietaire (via RPC `notify_nouvelle_demande`, best-effort —
  /// a demanda é criada mesmo se a notificação falhar) para que a nova demanda
  /// apareça na seção « Notifications » do tableau de bord.
  static Future<void> create({
    required String locataireId,
    required int immeubleId,
    int? chambreId,
  }) async {
    final payload = <String, dynamic>{
      'locataire_id': locataireId,
      'immeuble_id': immeubleId,
      'contact_etabli': false,
    };
    if (chambreId != null) payload['chambre_id'] = chambreId;
    final inserted =
        await _db.from(_table).insert(payload).select('id').single();
    _invalidate();
    try {
      await _db.rpc(
        'notify_nouvelle_demande',
        params: {'p_demande_id': inserted['id']},
      );
    } catch (_) {
      // best-effort
    }
  }

  /// Nouveau modèle « messagerie » : le locataire prend contact **et** envoie
  /// son premier message dans le même geste (plus d'acceptation préalable côté
  /// propriétaire). Crée la demande (statut `nouveau`), récupère le
  /// propriétaire (owner de l'immeuble — `Immeubles` a un SELECT public) puis
  /// envoie le message. Notifie le propriétaire (best-effort). Retourne l'id.
  static Future<int> createWithMessage({
    required String locataireId,
    required int immeubleId,
    int? chambreId,
    required String message,
  }) async {
    final payload = <String, dynamic>{
      'locataire_id': locataireId,
      'immeuble_id': immeubleId,
    };
    if (chambreId != null) payload['chambre_id'] = chambreId;
    final inserted = await _db
        .from(_table)
        .insert(payload)
        .select('id, Immeubles!immeuble_id(owner_id)')
        .single();
    final demandeId = inserted['id'] as int;
    final ownerId =
        (inserted['Immeubles'] as Map?)?['owner_id'] as String?;
    _invalidate();

    final texte = message.trim();
    if (texte.isNotEmpty && ownerId != null) {
      await MessagesDatasource.send(
        demandeId: demandeId,
        recipientId: ownerId,
        body: texte,
      );
    }
    try {
      await _db.rpc(
        'notify_nouvelle_demande',
        params: {'p_demande_id': demandeId},
      );
    } catch (_) {/* best-effort */}
    return demandeId;
  }

  /// Nom du propriétaire de l'annonce (pour le pop-up « Entrer en contact »,
  /// avant qu'une demande n'existe → RPC `annonce_proprietaire_nom`, réservée
  /// aux authentifiés). Renvoie null si indisponible.
  static Future<String?> proprietaireNom(int immeubleId) async {
    try {
      final res = await _db.rpc(
        'annonce_proprietaire_nom',
        params: {'p_immeuble_id': immeubleId},
      );
      return res as String?;
    } catch (_) {
      return null;
    }
  }

  // ── Statut (géré par le propriétaire ; RLS `proprietaire_update_demande`) ──

  /// Fixe le statut de la demande.
  static Future<void> setStatut(int id, StatutDemande statut) async {
    await _db.from(_table).update({'statut': statut.code}).eq('id', id);
    _invalidate();
  }

  /// Le propriétaire ignore la demande.
  static Future<void> ignorer(int id) => setStatut(id, StatutDemande.ignore);

  /// À l'ouverture du fil par le propriétaire : `nouveau` → `non_repondu`
  /// (« vu, pas encore répondu »). N'écrase pas `repondu`/`ignore`.
  static Future<void> markVu(int id) async {
    await _db
        .from(_table)
        .update({'statut': StatutDemande.nonRepondu.code})
        .eq('id', id)
        .eq('statut', StatutDemande.nouveau.code);
    _invalidate();
  }

  /// Quand le propriétaire répond → `repondu`.
  static Future<void> markRepondu(int id) =>
      setStatut(id, StatutDemande.repondu);

  /// Embeds partagés — **aucune donnée personnelle de personne**.
  ///
  /// Les embeds `Users_Client` ont été retirés : depuis la migration
  /// `demande_counterpart_profiles`, la politique RLS qui ouvrait la ligne
  /// entière de la contrepartie n'existe plus. L'identité de l'autre partie
  /// passe par [counterpartProfiles], qui applique les préférences de
  /// visibilité **côté serveur**. Conséquence directe : créer une demande sur
  /// une annonce ne donne plus accès aux coordonnées de son propriétaire.
  static const _select =
      '*, '
      'Chambres!chambre_id(room_name), '
      'Immeubles!immeuble_id(name, owner_id)';

  /// Fiche de la contrepartie pour chacune des [demandeIds], via la RPC
  /// `demande_counterpart_profiles` (`SECURITY DEFINER`).
  ///
  /// Le serveur ne renvoie que les champs que la personne concernée accepte de
  /// montrer : un champ masqué n'arrive **pas** dans la réponse, il n'est donc
  /// pas seulement caché à l'écran. Le nom, lui, est toujours renvoyé — sans
  /// lui on ne saurait pas à qui on écrit.
  ///
  /// Retourne une map `demandeId → fiche`. Une demande absente de la map =
  /// contrepartie indéterminée (l'appelant n'est pas partie à cette demande).
  static Future<Map<int, ProfileCardData>> counterpartProfiles(
    List<int> demandeIds, {
    bool refresh = false,
  }) {
    if (demandeIds.isEmpty) {
      return Future.value(const <int, ProfileCardData>{});
    }
    final key = '${CacheKeys.demandes}profiles:'
        '${(demandeIds.toList()..sort()).join(",")}';
    return _cache.get(key, () async {
      final rows = await _db.rpc(
        'demande_counterpart_profiles',
        params: {'p_demande_ids': demandeIds},
      ) as List;
      return {
        for (final r in rows)
          (r as Map)['demande_id'] as int: ProfileCardData.preFiltered(
            userId: r['user_id'] as String?,
            fullName: r['full_name'] as String?,
            age: (r['age'] as num?)?.toInt(),
            phone: r['phone'] as String?,
            email: r['email'] as String?,
          ),
      };
    }, refresh: refresh);
  }

  /// Lista todas as demandas para os imóveis do proprietaire autenticado.
  static Future<List<DemandeContactModel>> listByOwner({
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.demandes}owner', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .order('created_at', ascending: false);

      return rows
          .map((r) => DemandeContactModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }, refresh: refresh);
  }

  /// Lista as demandas feitas pelo locataire autenticado (RLS
  /// `locataire_select_demande` já limita ao próprio).
  static Future<List<DemandeContactModel>> listByLocataire({
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.demandes}locataire', () async {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return <DemandeContactModel>[];
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('locataire_id', uid)
          .order('created_at', ascending: false);

      return rows
          .map((r) => DemandeContactModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }, refresh: refresh);
  }

  /// Une demande par son id (RLS : seules les deux parties la voient).
  /// Sert à ouvrir un fil désigné depuis un autre écran (fiche d'annonce,
  /// notification) sans avoir chargé toute la liste.
  static Future<DemandeContactModel?> byId(int id) async {
    final row =
        await _db.from(_table).select(_select).eq('id', id).maybeSingle();
    if (row == null) return null;
    return DemandeContactModel.fromJson(Map<String, dynamic>.from(row));
  }

  /// Atualiza o campo contact_etabli de uma demanda.
  ///
  /// C'est **l'acceptation** : à `true`, le fil de discussion s'ouvre pour les
  /// deux parties (la RLS de `Messages` s'appuie sur ce champ).
  static Future<void> updateContactEtabli(int id, {required bool value}) async {
    await _db.from(_table).update({'contact_etabli': value}).eq('id', id);
    _invalidate();
  }

  /// Id du fil **déjà ouvert** (non ignoré) entre ce locataire et cette
  /// annonce — `null` s'il n'y en a pas encore.
  ///
  /// Sert au bouton de la fiche d'annonce : avoir déjà écrit ne doit **pas**
  /// bloquer le locataire (l'ancien libellé « Vous avez déjà contacté le
  /// propriétaire » désactivait le bouton, cul-de-sac). Un fil existant → on
  /// rouvre la discussion avec tout son historique ; sinon → nouveau contact.
  ///
  /// [chambreId] preenchido → escopo à chambre (fiche chambre). Nulo → escopo
  /// ao imóvel inteiro (annonce d'immeuble, sem chambre alvo) : nesse caso só
  /// contam as demandas **sem** chambre para o mesmo imóvel, para não confundir
  /// um contato ao imóvel com uma conversa sobre uma chambre específica.
  static Future<int?> existingDemandeId({
    required String locataireId,
    int? chambreId,
    int? immeubleId,
  }) async {
    var query = _db
        .from(_table)
        .select('id')
        .eq('locataire_id', locataireId)
        .neq('statut', StatutDemande.ignore.code);
    if (chambreId != null) {
      query = query.eq('chambre_id', chambreId);
    } else if (immeubleId != null) {
      query = query.eq('immeuble_id', immeubleId).isFilter('chambre_id', null);
    } else {
      return null;
    }
    final res = await query.order('created_at', ascending: false).limit(1);
    final rows = res as List;
    return rows.isEmpty ? null : (rows.first as Map)['id'] as int;
  }
}
