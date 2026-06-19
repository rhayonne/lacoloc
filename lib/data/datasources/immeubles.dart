import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ImmeublesDatasource {
  ImmeublesDatasource._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _table = 'Immeubles';
  static const String _selectWithType =
      '*, Immeuble_Types_Reference!type_id(id, name)';

  static final _cache = DataCache.instance;

  /// Vide tout le cache des immeubles (après un write).
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.immeubles);

  /// Lista pública: apenas imóveis ativos.
  static Future<List<ImmeublesModel>> listAll({bool refresh = false}) {
    return _cache.get(
      '${CacheKeys.immeubles}all',
      () async {
        final rows = await _client
            .from(_table)
            .select(_selectWithType)
            .eq('is_active', true)
            .order('created_at', ascending: false);
        return _map(rows);
      },
      refresh: refresh,
    );
  }

  /// Lista do proprietário: todos os imóveis (ativos e inativos).
  ///
  /// **Multi-tenant**: se o usuário pertence a uma empresa (`entreprise_id`),
  /// retorna **todos os imóveis da empresa** (todos os membros veem tudo); caso
  /// contrário, apenas os imóveis cujo `owner_id` é o usuário.
  static Future<List<ImmeublesModel>> listByOwner(
    String ownerId, {
    bool refresh = false,
  }) {
    return _cache.get(
      '${CacheKeys.immeubles}owner:$ownerId',
      () async {
        final entrepriseId = await _entrepriseIdOf(ownerId);
        final query = _client.from(_table).select(_selectWithType);
        final filtered = entrepriseId != null
            ? query.eq('entreprise_id', entrepriseId)
            : query.eq('owner_id', ownerId);
        final rows = await filtered.order('created_at', ascending: false);
        return _map(rows);
      },
      refresh: refresh,
    );
  }

  /// `entreprise_id` do usuário (cache em memória). RLS permite ler a própria
  /// linha (`id = auth.uid()`), que é o caso aqui (ownerId = usuário atual).
  static final Map<String, int?> _entrepriseCache = {};
  static Future<int?> _entrepriseIdOf(String userId) async {
    if (_entrepriseCache.containsKey(userId)) return _entrepriseCache[userId];
    final row = await _client
        .from('Users_Client')
        .select('entreprise_id')
        .eq('id', userId)
        .maybeSingle();
    final id = (row?['entreprise_id'] as num?)?.toInt();
    _entrepriseCache[userId] = id;
    return id;
  }

  /// Limpa o cache de empresa (ex.: no logout).
  static void clearEntrepriseCache() => _entrepriseCache.clear();

  static Future<ImmeublesModel?> byId(int id, {bool refresh = false}) {
    return _cache.get(
      '${CacheKeys.immeubles}id:$id',
      () async {
        final row = await _client
            .from(_table)
            .select(_selectWithType)
            .eq('id', id)
            .maybeSingle();
        return row == null ? null : ImmeublesModel.fromMap(row);
      },
      refresh: refresh,
    );
  }

  static Future<ImmeublesModel> create(ImmeublesModel input) async {
    final inserted = await _client
        .from(_table)
        .insert(input.toInsert())
        .select(_selectWithType)
        .single();
    _invalidate();
    return ImmeublesModel.fromMap(inserted);
  }

  static Future<ImmeublesModel> update(ImmeublesModel input) async {
    final updated = await _client
        .from(_table)
        .update(input.toInsert())
        .eq('id', input.id)
        .select(_selectWithType)
        .single();
    _invalidate();
    return ImmeublesModel.fromMap(updated);
  }

  /// Supprime un immeuble et son contenu directement rattaché (inventaire,
  /// pièces, chambres, charges). **Bloqué** s'il existe des états des lieux liés
  /// (un immeuble avec contrats ne doit pas être supprimé). Utilisé notamment à
  /// la fin du **tour guidé** (« supprimer l'immeuble d'essai »).
  static Future<void> delete(int id) async {
    // Garde : pas de suppression si des EDL référencent l'immeuble.
    final edl = await _client
        .from('etat_de_lieux')
        .select('id')
        .eq('immeuble_id', id)
        .limit(1);
    if ((edl as List).isNotEmpty) {
      throw Exception(
        "Impossible de supprimer : cet immeuble a des états des lieux liés.",
      );
    }
    // Contenu rattaché — enfants d'abord pour respecter les FK.
    await _client.from('Inventaire').delete().eq('immeuble_id', id);
    await _client.from('Pieces').delete().eq('immeuble_id', id);
    await _client.from('Chambres').delete().eq('immeuble_id', id);
    await _client.from('Immeuble_Charges').delete().eq('immeuble_id', id);
    await _client.from(_table).delete().eq('id', id);
    // Invalide les caches impactés.
    _cache.invalidatePrefix(CacheKeys.immeubles);
    _cache.invalidatePrefix(CacheKeys.chambres);
    _cache.invalidatePrefix(CacheKeys.pieces);
    _cache.invalidatePrefix(CacheKeys.inventaire);
    _cache.invalidatePrefix(CacheKeys.immeubleCharges);
  }

  static List<ImmeublesModel> _map(List rows) =>
      rows.map((r) => ImmeublesModel.fromMap(r as Map<String, dynamic>)).toList();
}
