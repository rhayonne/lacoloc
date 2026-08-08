import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/models/plage_ouverture.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Plages de disponibilité du propriétaire (par jour de semaine). Petite table
/// (RLS owner-only) — lecture directe, sans cache.
class PlagesOuvertureDatasource {
  PlagesOuvertureDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Plages_Ouverture';

  static Future<List<PlageOuverture>> listByOwner() async {
    final rows = await _db
        .from(_table)
        .select()
        .order('jour_semaine', ascending: true)
        .order('heure_debut', ascending: true);
    return rows
        .map((r) => PlageOuverture.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  static Future<PlageOuverture> create(PlageOuverture p) async {
    final ownerId = AuthService.currentUser!.id;
    final row = await _db
        .from(_table)
        .insert(p.toInsert(ownerId))
        .select()
        .single();
    return PlageOuverture.fromMap(Map<String, dynamic>.from(row));
  }

  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
  }

  /// Remplace toutes les plages du propriétaire par [plages] (transaction
  /// logique : suppression puis insertion en lot).
  static Future<List<PlageOuverture>> replaceAll(
      List<PlageOuverture> plages) async {
    final ownerId = AuthService.currentUser!.id;
    await _db.from(_table).delete().eq('owner_id', ownerId);
    if (plages.isEmpty) return [];
    final payload = plages.map((p) => p.toInsert(ownerId)).toList();
    final rows = await _db.from(_table).insert(payload).select();
    return rows
        .map((r) => PlageOuverture.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }
}
