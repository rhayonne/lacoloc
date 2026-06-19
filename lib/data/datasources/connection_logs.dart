import 'package:lacoloc_front/data/models/connection_log.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConnectionLogsDatasource {
  static final _db = Supabase.instance.client;
  static const _table = 'connection_logs';

  /// Liste les logs, du plus récent au plus ancien.
  /// Filtres optionnels : [search] sur email/nom/IP, [userType], plage de dates.
  static Future<List<ConnectionLog>> list({
    int limit = 100,
    int offset = 0,
    String? search,
    String? userType,
    DateTime? from,
    DateTime? to,
  }) async {
    // Tous les filtres doivent être appliqués AVANT .order()/.range()
    // car ceux-ci retournent un PostgrestTransformBuilder sans méthodes de filtre.
    var query = _db.from(_table).select();

    if (search != null && search.isNotEmpty) {
      // On retire les caractères significatifs de la grammaire de filtre PostgREST
      // (',' '(' ')' ':' '*') pour empêcher toute manipulation/casse du filtre `.or()`.
      final s = search.trim().replaceAll(RegExp(r'[,()*:]'), '');
      if (s.isNotEmpty) {
        query = query.or(
          'user_email.ilike.%$s%,user_name.ilike.%$s%,ip_address.ilike.%$s%',
        );
      }
    }
    if (userType != null && userType.isNotEmpty) {
      query = query.eq('user_type', userType);
    }
    if (from != null) {
      query = query.gte('created_at', from.toUtc().toIso8601String());
    }
    if (to != null) {
      final endOfDay = DateTime(to.year, to.month, to.day, 23, 59, 59);
      query = query.lte('created_at', endOfDay.toUtc().toIso8601String());
    }

    final rows = await query
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return rows.map((r) => ConnectionLog.fromMap(r)).toList();
  }
}
