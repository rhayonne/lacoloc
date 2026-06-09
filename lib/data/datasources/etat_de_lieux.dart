import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lacoloc_front/config/env_config.dart';
import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/datasources/chambres.dart';
import 'package:lacoloc_front/data/datasources/edl_details.dart';
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
      'proprietaire:Users_Client!proprietaire_id(id, full_name), '
      'preneurs:etat_de_lieux_preneurs(nom, locataire:Users_Client!locataire_id(full_name))';

  static Future<List<EtatDesLieuxModel>> listByProprietaire(
    String proprietaireId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.edl}prop:$proprietaireId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('proprietaire_id', proprietaireId)
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

  /// União dos EDLs do locataire: privatifs (`locataire_id`) + collectifs onde
  /// é preneur. Deduplicado por id.
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
  /// Après la mise à jour de l'EDL, marque la chambre comme occupée (`est_loue`).
  static Future<void> finaliser(
    int id, {
    DateTime? dateDebutBail,
    DateTime? dateFinBail,
    int? dureeBailMois,
    int? chambreId,
  }) async {
    final updates = <String, dynamic>{
      'situation': SituationEdl.finalise.raw,
      if (dateDebutBail != null)
        'date_debut_bail': dateDebutBail.toIso8601String().substring(0, 10),
      if (dateFinBail != null)
        'date_fin_bail': dateFinBail.toIso8601String().substring(0, 10),
      'duree_bail_mois': ?dureeBailMois,
    };
    await _db.from(_table).update(updates).eq('id', id);
    if (chambreId case final id?) {
      await ChambresDatasource.setOccupied(id, occupied: true);
    }
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
  static Future<List<AmendableCollectif>> listAmendableCollectifs(
    String proprietaireId, {
    String typeEdl = 'entree',
  }) async {
    final all = await listByProprietaire(proprietaireId, refresh: true);
    final collectifs = all.where((e) =>
        e.partie == PartieEdl.commune &&
        e.typeBail == 'individuel' &&
        e.typeEdl == typeEdl &&
        e.situation == SituationEdl.finalise);

    final out = <AmendableCollectif>[];
    for (final c in collectifs) {
      final chambres = await ChambresDatasource.listByImmeuble(c.immeubleId);
      final privatifs = await listPrivativesByCollectif(c.id);
      final usedChambreIds =
          privatifs.map((p) => p.chambreId).whereType<int>().toSet();
      final free = chambres
          .where((ch) => ch.isActive && !usedChambreIds.contains(ch.id))
          .toList();
      if (free.isEmpty) continue;
      out.add(AmendableCollectif(
        collectif: c,
        freeChambres: free,
        firstSignedDate: await firstSignedContractDate(c.id),
      ));
    }
    return out;
  }

  static Future<void> locataireAccepter(int id) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db.from(_table).update({
      'locataire_accepte': true,
      'date_finalisation': today,
    }).eq('id', id);
    invalidate();
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
    final row = await _db
        .from('Users_Client')
        .select('id')
        .eq('email', email)
        .maybeSingle();
    return row != null;
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

  /// Teste de diagnostic SMTP — envoie **uniquement** un e-mail de test
  /// (aucun compte créé). Retourne la réponse brute de la fonction edge :
  /// `{ emailSent, recipient, smtpConfigured, smtpError? }`.
  ///
  /// Exemple :
  /// ```dart
  /// final r = await EtatDesLieuxDatasource.testInviteEmail('moi@exemple.com');
  /// debugPrint('$r'); // emailSent: true/false + smtpError éventuel
  /// ```
  static Future<Map<String, dynamic>> testInviteEmail(String to) async {
    final res = await Supabase.instance.client.functions.invoke(
      'invite-locataire',
      body: {'test': true, 'fullName': 'Test La Coloc', 'email': to},
    );
    return Map<String, dynamic>.from(res.data as Map);
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
  static Future<void> resendInvitation({
    required String userId,
    required String email,
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
      },
    );
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error']);
    }
  }
}

/// Résultat de [EtatDesLieuxDatasource.listAmendableCollectifs] : un collectif
/// finalisé qui peut encore recevoir un avenant, ses chambres libres et la date
/// du premier contrat signé.
class AmendableCollectif {
  final EtatDesLieuxModel collectif;
  final List<ChambreModel> freeChambres;
  final DateTime? firstSignedDate;

  const AmendableCollectif({
    required this.collectif,
    required this.freeChambres,
    this.firstSignedDate,
  });
}
