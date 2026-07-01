import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lacoloc_front/config/env_config.dart';
import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/visite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VisitesDatasource {
  VisitesDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Visites';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.visites);

  static Future<List<VisiteModel>> listByOwner({bool refresh = false}) {
    return _cache.get('${CacheKeys.visites}owner', () async {
      final rows = await _db
          .from(_table)
          .select()
          .order('heure_debut', ascending: true, nullsFirst: false);
      return rows
          .map((r) => VisiteModel.fromMap(Map<String, dynamic>.from(r)))
          .toList();
    }, refresh: refresh);
  }

  static Future<VisiteModel> create(VisiteModel v) async {
    final row =
        await _db.from(_table).insert(v.toInsert()).select().single();
    _invalidate();
    return VisiteModel.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<VisiteModel> update(VisiteModel v) async {
    final row = await _db
        .from(_table)
        .update(v.toInsert())
        .eq('id', v.id)
        .select()
        .single();
    _invalidate();
    return VisiteModel.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }

  /// Envoie l'e-mail d'invitation au contact du rendez-vous (locataire lié ou
  /// invité hors système). Best-effort. En dev, redirigé vers la boîte de test.
  static Future<void> notifyRendezvous(int visiteId) async {
    try {
      await _db.functions.invoke(
        'notify-rendezvous',
        body: {
          'visiteId': visiteId,
          'mailTo': ?_devMailOverride,
        },
      );
    } catch (_) {
      // best-effort
    }
  }

  static String? get _devMailOverride {
    if (!EnvConfig.isDev) return null;
    final addr = dotenv.get('ADDR_MAIL_CONFIRMATION', fallback: '').trim();
    return addr.isEmpty ? null : addr;
  }
}
