import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/fournisseur.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentTypesDatasource {
  PaymentTypesDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static final _cache = DataCache.instance;
  static const String _table = 'Payment_Types_Reference';
  static const _ttl = Duration(minutes: 30);

  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.paymentTypes);

  static Future<List<PaymentTypeRef>> listAll() {
    return _cache.get('${CacheKeys.paymentTypes}all', () async {
      final rows = await _client
          .from(_table)
          .select()
          .order('id', ascending: true);
      return rows.map((r) => PaymentTypeRef.fromMap(r)).toList();
    }, ttl: _ttl);
  }

  static Future<PaymentTypeRef> create({
    required String code,
    required String label,
    String? description,
  }) async {
    final inserted = await _client
        .from(_table)
        .insert({'code': code, 'label': label, 'description': description})
        .select()
        .single();
    _invalidate();
    return PaymentTypeRef.fromMap(inserted);
  }

  static Future<PaymentTypeRef> update({
    required int id,
    required String code,
    required String label,
    String? description,
  }) async {
    final updated = await _client
        .from(_table)
        .update({'code': code, 'label': label, 'description': description})
        .eq('id', id)
        .select()
        .single();
    _invalidate();
    return PaymentTypeRef.fromMap(updated);
  }

  static Future<void> delete(int id) async {
    await _client.from(_table).delete().eq('id', id);
    _invalidate();
  }
}
