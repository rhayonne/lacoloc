import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lacoloc_front/config/env_config.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EtatDesLieuxDatasource {
  EtatDesLieuxDatasource._();

  static final _db = Supabase.instance.client;

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
      'immeuble:Immeubles!immeuble_id(id, name, address), '
      'chambre:Chambres!chambre_id(id, room_name), '
      'proprietaire:Users_Client!proprietaire_id(id, full_name)';

  static Future<List<EtatDesLieuxModel>> listByProprietaire(
    String proprietaireId,
  ) async {
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('proprietaire_id', proprietaireId)
        .order('date_etat_lieux', ascending: false);
    return rows.map((r) => EtatDesLieuxModel.fromMap(r)).toList();
  }

  static Future<List<EtatDesLieuxModel>> listByLocataire(
    String locataireId,
  ) async {
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('locataire_id', locataireId)
        .order('date_etat_lieux', ascending: false);
    return rows.map((r) => EtatDesLieuxModel.fromMap(r)).toList();
  }

  static Future<EtatDesLieuxModel> create(EtatDesLieuxModel m) async {
    final row = await _db
        .from(_table)
        .insert(m.toInsert())
        .select(_select)
        .single();
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
        .maybeSingle();
    return row == null ? null : EtatDesLieuxModel.fromMap(row);
  }

  /// Garante a existência do EDL collectif do imóvel e devolve seu id.
  /// Usado ao criar um EDL privatif (bail individuel): cada chambre tem seu EDL
  /// privatif ligado a este collectif compartilhado.
  static Future<int> ensureCollectif(EtatDesLieuxModel commune) async {
    final existing = await findCollectif(
      immeubleId: commune.immeubleId,
      typeEdl: commune.typeEdl,
    );
    if (existing != null) return existing.id;
    final created = await create(commune);
    return created.id;
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
    return EtatDesLieuxModel.fromMap(row);
  }

  static Future<void> finaliser(int id) async {
    await _db.from(_table).update({
      'situation': SituationEdl.finalise.raw,
    }).eq('id', id);
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
  }

  static Future<void> locataireAccepter(int id) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db.from(_table).update({
      'locataire_accepte': true,
      'date_finalisation': today,
    }).eq('id', id);
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
}
