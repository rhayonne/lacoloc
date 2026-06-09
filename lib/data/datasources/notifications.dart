import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/notification_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notifications in-app du propriétaire. La lecture/maj passe par les policies
/// RLS ; la création est faite côté locataire via la RPC `notify_edl_proprietaire`
/// (SECURITY DEFINER), qui dérive le destinataire du proprietaire de l'EDL.
class NotificationsDatasource {
  NotificationsDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Notifications';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.notifications);

  static Future<List<NotificationModel>> listByOwner({
    int limit = 50,
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.notifications}owner:$limit', () async {
      final rows = await _db
          .from(_table)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(NotificationModel.fromMap).toList();
    }, refresh: refresh);
  }

  static Future<int> unreadCount() async {
    final rows = await _db.from(_table).select('id').eq('is_read', false);
    return (rows as List).length;
  }

  static Future<void> markRead(int id) async {
    await _db.from(_table).update({'is_read': true}).eq('id', id);
    _invalidate();
  }

  static Future<void> markAllRead() async {
    await _db.from(_table).update({'is_read': true}).eq('is_read', false);
    _invalidate();
  }

  /// Crée une notification pour le propriétaire de l'EDL (appelé côté locataire).
  /// Best-effort : ne doit pas bloquer le flux d'acceptation.
  static Future<void> notifyEdlProprietaire({
    required int edlId,
    required String type,
    required String title,
    String? body,
  }) async {
    try {
      await _db.rpc('notify_edl_proprietaire', params: {
        'p_edl_id': edlId,
        'p_type': type,
        'p_title': title,
        'p_body': body,
      });
    } catch (_) {
      // best-effort
    }
  }
}
