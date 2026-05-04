import 'package:lacoloc_front/data/models/fournisseur.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FournisseursDatasource {
  FournisseursDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'Fournisseurs';
  static const String _facturesTable = 'Factures';
  static const String _paymentTypesTable = 'Payment_Types_Reference';

  static Future<List<FournisseurModel>> listByOwner(String ownerId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('owner_id', ownerId)
        .order('nom', ascending: true);
    return _map(rows);
  }

  static Future<List<FournisseurModel>> listActiveByOwner(
      String ownerId) async {
    final rows = await _client
        .from(_table)
        .select()
        .eq('owner_id', ownerId)
        .eq('is_active', true)
        .order('nom', ascending: true);
    return _map(rows);
  }

  static Future<List<PaymentTypeRef>> listPaymentTypes() async {
    final rows = await _client
        .from(_paymentTypesTable)
        .select()
        .order('id', ascending: true);
    return rows
        .map((r) => PaymentTypeRef.fromMap(r))
        .toList();
  }

  static Future<FournisseurModel> create(FournisseurModel input) async {
    final inserted = await _client
        .from(_table)
        .insert(input.toInsert())
        .select()
        .single();
    return FournisseurModel.fromMap(inserted);
  }

  static Future<FournisseurModel> update(FournisseurModel input) async {
    final updated = await _client
        .from(_table)
        .update(input.toInsert())
        .eq('id', input.id)
        .select()
        .single();
    return FournisseurModel.fromMap(updated);
  }

  /// Retorna true se há ao menos uma facture com este nome de fournisseur.
  static Future<bool> hasFactures(String nomFournisseur) async {
    final result = await _client
        .from(_facturesTable)
        .select('id')
        .eq('fournisseur', nomFournisseur)
        .limit(1);
    return (result as List).isNotEmpty;
  }

  static Future<void> delete(int id) async {
    await _client.from(_table).delete().eq('id', id);
  }

  static List<FournisseurModel> _map(List rows) =>
      rows.map((r) => FournisseurModel.fromMap(r as Map<String, dynamic>)).toList();
}
