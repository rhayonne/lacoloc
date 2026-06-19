import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/immeuble_charge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImmeubleChargesDatasource {
  static final _db = Supabase.instance.client;
  static final _cache = DataCache.instance;
  static const _table = 'Immeuble_Charges';
  static const _select = '*, Charges_Reference(id, nom, icone, description, is_active, ordre)';

  static void _invalidate() =>
      _cache.invalidatePrefix(CacheKeys.immeubleCharges);

  static Future<List<ImmeubleChargeModel>> listByImmeuble(int immeubleId) {
    return _cache.get('${CacheKeys.immeubleCharges}immeuble:$immeubleId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('immeuble_id', immeubleId)
          .order('id');
      return (rows as List)
          .map((r) => ImmeubleChargeModel.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    });
  }

  /// Upsert : crée ou met à jour la charge pour cet immeuble.
  static Future<void> upsert(ImmeubleChargeModel model) async {
    await _db.from(_table).upsert(
      model.toInsert(),
      onConflict: 'immeuble_id,charge_ref_id',
    );
    _invalidate();
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }

  static Future<void> deleteByImmeuble(int immeubleId) async {
    await _db.from(_table).delete().eq('immeuble_id', immeubleId);
    _invalidate();
  }
}
