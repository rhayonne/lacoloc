import 'package:lacoloc_front/data/models/admin_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Diffusion de messages in-app par le super admin (apparaissent dans le
/// tableau de bord + menu « Messages » des destinataires) et historique des
/// envois.
///
/// L'audience est résolue côté application (tous / par type / par groupe /
/// utilisateurs spécifiques) ; on transmet ici la liste explicite des
/// destinataires à la RPC `admin_broadcast_notification` (SECURITY DEFINER,
/// réservée au super admin). La RPC enregistre aussi le message dans
/// `Admin_Messages` (historique).
class CommunicationDatasource {
  CommunicationDatasource._();

  static final _db = Supabase.instance.client;

  /// Type de notification utilisé pour les messages du super admin.
  static const messageType = 'admin_message';

  /// Envoie [title]/[body] (+ média optionnel) à chaque utilisateur de
  /// [recipientIds]. [audienceLabel] décrit l'audience (pour l'historique).
  /// Retourne l'id du message créé (Admin_Messages).
  static Future<int> sendMessage({
    required List<String> recipientIds,
    required String title,
    String? body,
    String? mediaType,
    String? mediaUrl,
    String? audienceLabel,
  }) async {
    final res = await _db.rpc('admin_broadcast_notification', params: {
      'p_recipient_ids': recipientIds,
      'p_type': messageType,
      'p_title': title,
      'p_body': body,
      'p_media_type': mediaType,
      'p_media_url': mediaUrl,
      'p_audience': audienceLabel,
    });
    if (res is int) return res;
    return 0;
  }

  /// Historique des messages diffusés (super admin uniquement, via RLS).
  static Future<List<AdminMessage>> listSentMessages({int limit = 100}) async {
    final rows = await _db
        .from('Admin_Messages')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((r) => AdminMessage.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
