import 'package:supabase_flutter/supabase_flutter.dart';

/// Escopo da sessão atual para queries multi-tenant.
///
/// Resolve (e cacheia) o `entreprise_id` do usuário autenticado. Os datasources
/// usam isto para decidir entre listar por **empresa** (membro de uma empresa →
/// vê tudo da empresa) ou por **dono** (`owner_id`/`proprietaire_id`).
///
/// Limpar no logout via [clear] (em `my_app.dart`).
class SessionScope {
  SessionScope._();

  static final _db = Supabase.instance.client;
  static final Map<String, int?> _cache = {};

  /// `entreprise_id` do usuário atual (ou null). RLS permite ler a própria linha.
  static Future<int?> currentEntrepriseId() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;
    if (_cache.containsKey(uid)) return _cache[uid];
    final row = await _db
        .from('Users_Client')
        .select('entreprise_id')
        .eq('id', uid)
        .maybeSingle();
    final id = (row?['entreprise_id'] as num?)?.toInt();
    _cache[uid] = id;
    return id;
  }

  static void clear() => _cache.clear();
}
