import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Messagerie rattachée à une demande de contact (un fil par demande).
///
/// Le fil ne s'ouvre qu'une fois la demande acceptée par le proprietaire
/// (`Demandes_Contact.contact_etabli`) — c'est la **RLS** qui l'impose à
/// l'insertion, l'UI ne fait que refléter la règle.
class MessagesDatasource {
  MessagesDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Messages';
  static const _select = '*, sender:Users_Client!sender_id(full_name)';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.messages);

  /// Fil complet d'une demande, du plus ancien au plus récent.
  static Future<List<MessageModel>> listByDemande(
    int demandeId, {
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.messages}demande:$demandeId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('demande_id', demandeId)
          .order('created_at', ascending: true);
      return rows
          .map((r) => MessageModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }, refresh: refresh);
  }

  /// Envoie un message. [recipientId] est l'autre partie de la demande
  /// (cf. `DemandeContactModel.interlocuteurId`).
  ///
  /// Lève une exception si la demande n'est pas acceptée (refus RLS).
  static Future<void> send({
    required int demandeId,
    required String recipientId,
    required String body,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw Exception('Non authentifié');
    final texte = body.trim();
    if (texte.isEmpty) return;

    await _db.from(_table).insert({
      'demande_id': demandeId,
      'sender_id': uid,
      'recipient_id': recipientId,
      'body': texte,
    });
    _invalidate();
  }

  /// Marque comme lus les messages **reçus** dans ce fil. Sans effet sur les
  /// miens (la RLS réserve l'update au destinataire).
  static Future<void> markReadForDemande(int demandeId) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _db
        .from(_table)
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('demande_id', demandeId)
        .eq('recipient_id', uid)
        .isFilter('read_at', null);
    _invalidate();
  }

  /// Nombre total de messages reçus non lus (badge du menu Interactions).
  static Future<int> unreadCount({bool refresh = false}) {
    return _cache.get('${CacheKeys.messages}unread', () async {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return 0;
      final rows = await _db
          .from(_table)
          .select('id')
          .eq('recipient_id', uid)
          .isFilter('read_at', null);
      return (rows as List).length;
    }, refresh: refresh);
  }

  /// Nombre de messages non lus **par demande** (pastille sur chaque fil).
  /// Une seule requête pour toute la liste — pas de N+1.
  static Future<Map<int, int>> unreadCountByDemande({
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.messages}unread:by_demande', () async {
      final uid = _db.auth.currentUser?.id;
      if (uid == null) return <int, int>{};
      final rows = await _db
          .from(_table)
          .select('demande_id')
          .eq('recipient_id', uid)
          .isFilter('read_at', null);
      final counts = <int, int>{};
      for (final r in rows) {
        final id = r['demande_id'] as int;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      return counts;
    }, refresh: refresh);
  }

  /// Texte concaténé de chaque fil (pour la recherche « Mes discussions » /
  /// « Demandes de contact » — nom de l'interlocuteur + contenu des messages).
  ///
  /// Aucun filtre explicite sur sender/recipient n'est nécessaire : la RLS de
  /// `Messages` (`auth.uid() IN (sender_id, recipient_id)`) restreint déjà le
  /// SELECT aux messages qu'on a **envoyés ou reçus** — impossible de faire
  /// remonter ici un message ou un fil auquel on n'a jamais participé.
  static Future<Map<int, String>> searchableTextByDemande(
    List<int> demandeIds, {
    bool refresh = false,
  }) {
    if (demandeIds.isEmpty) return Future.value({});
    final sorted = [...demandeIds]..sort();
    return _cache.get(
      '${CacheKeys.messages}searchtext:${sorted.join(",")}',
      () async {
        final rows = await _db
            .from(_table)
            .select('demande_id, body')
            .inFilter('demande_id', sorted);
        final map = <int, StringBuffer>{};
        for (final r in rows) {
          final id = r['demande_id'] as int;
          (map[id] ??= StringBuffer()).write('${r['body']} ');
        }
        return map.map((k, v) => MapEntry(k, v.toString()));
      },
      refresh: refresh,
    );
  }

  /// Supprime un de ses propres messages (RLS : expéditeur uniquement).
  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }
}
