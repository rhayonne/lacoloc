import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/chambre_charge.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChambreChargesDatasource {
  static final _db = Supabase.instance.client;
  static final _cache = DataCache.instance;
  static const _table = 'Chambre_Charges';
  static const _select = '*, Charges_Reference(id, nom, icone, description, is_active, ordre)';

  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.chambreCharges);

  static Future<List<ChambreChargeModel>> listByChambre(int chambreId) {
    return _cache.get('${CacheKeys.chambreCharges}chambre:$chambreId', () async {
      final rows = await _db
          .from(_table)
          .select(_select)
          .eq('chambre_id', chambreId)
          .order('id');
      return (rows as List)
          .map((r) => ChambreChargeModel.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList();
    });
  }

  static Future<void> upsert(ChambreChargeModel model) async {
    await _db.from(_table).upsert(
      model.toInsert(),
      onConflict: 'chambre_id,charge_ref_id',
    );
    _invalidate();
  }

  /// Copie les charges de l'immeuble vers une chambre nouvellement créée.
  /// Idempotent : ignore si la chambre a déjà des charges.
  static Future<void> copyFromImmeuble({
    required int chambreId,
    required List<({int chargeRefId, String type, double? montant})> charges,
  }) async {
    if (charges.isEmpty) return;
    final existing = await listByChambre(chambreId);
    if (existing.isNotEmpty) return;
    await _db.from(_table).insert(charges
        .map((c) => {
              'chambre_id': chambreId,
              'charge_ref_id': c.chargeRefId,
              'type': c.type,
              if (c.montant != null) 'montant': c.montant,
            })
        .toList());
    _invalidate();
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }

  static Future<void> deleteByChambre(int chambreId) async {
    await _db.from(_table).delete().eq('chambre_id', chambreId);
    _invalidate();
  }

  /// Charge en lot les charges de plusieurs chambres (listing public).
  static Future<Map<int, List<ChambreChargeModel>>> listByChambres(List<int> chambreIds) async {
    if (chambreIds.isEmpty) return {};
    final rows = await _db
        .from(_table)
        .select(_select)
        .inFilter('chambre_id', chambreIds);
    final result = <int, List<ChambreChargeModel>>{};
    for (final r in rows as List) {
      final model = ChambreChargeModel.fromMap(Map<String, dynamic>.from(r as Map));
      result.putIfAbsent(model.chambreId, () => []).add(model);
    }
    return result;
  }
}
