import 'package:lacoloc_front/data/models/fournisseur.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentTypesDatasource {
  PaymentTypesDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'Payment_Types_Reference';

  static Future<List<PaymentTypeRef>> listAll() async {
    final rows = await _client
        .from(_table)
        .select()
        .order('id', ascending: true);
    return rows.map((r) => PaymentTypeRef.fromMap(r)).toList();
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
    return PaymentTypeRef.fromMap(updated);
  }

  static Future<void> delete(int id) async {
    await _client.from(_table).delete().eq('id', id);
  }
}
