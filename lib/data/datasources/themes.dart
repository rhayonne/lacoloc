import 'package:habitafrance/data/cache/data_cache.dart';
import 'package:habitafrance/data/cache/realtime_service.dart';
import 'package:habitafrance/data/models/theme_ref.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Accès aux thèmes (`Themes_Reference`).
///
/// Lecture **publique** (RLS) : un visiteur non connecté doit pouvoir charger
/// le thème par défaut avant toute session. Écriture réservée au super admin.
class ThemesDatasource {
  ThemesDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Themes_Reference';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.themes);

  /// Tous les thèmes, actifs ou non (écran d'administration).
  static Future<List<ThemeRef>> listAll({bool refresh = false}) {
    return _cache.get('${CacheKeys.themes}all', () async {
      final rows = await _db.from(_table).select().order('ordre').order('id');
      return rows.map(ThemeRef.fromMap).toList();
    }, refresh: refresh);
  }

  /// Les thèmes proposés aux utilisateurs dans « Mon profil ».
  static Future<List<ThemeRef>> listActive({bool refresh = false}) async {
    final all = await listAll(refresh: refresh);
    return all.where((t) => t.isActive).toList();
  }

  /// Le thème des visiteurs et des nouveaux comptes. `null` si la base est
  /// injoignable — l'appelant retombe alors sur la palette par défaut du code.
  static Future<ThemeRef?> defaultTheme({bool refresh = false}) async {
    final all = await listAll(refresh: refresh);
    return all.where((t) => t.isDefault && t.isActive).firstOrNull ??
        all.where((t) => t.isActive).firstOrNull;
  }

  static Future<ThemeRef> create(ThemeRef t) async {
    final row = await _db.from(_table).insert(t.toInsert()).select().single();
    _invalidate();
    return ThemeRef.fromMap(row);
  }

  /// Met à jour le libellé/la description/les couleurs d'un thème.
  /// (Les couleurs d'un thème intégré ne sont pas modifiables : elles vivent
  /// dans le code.)
  static Future<void> update(int id, ThemeRef t) async {
    final data = t.toInsert()..remove('code');
    await _db.from(_table).update(data).eq('id', id);
    _invalidate();
  }

  static Future<void> setActive(int id, bool active) async {
    await _db.from(_table).update({'is_active': active}).eq('id', id);
    _invalidate();
  }

  /// Désigne [id] comme thème par défaut. Un index unique en base garantit
  /// qu'il n'y en a qu'un : on retire donc l'ancien avant de poser le nouveau.
  /// Un thème par défaut est forcément actif — sinon les visiteurs n'auraient
  /// aucun thème.
  static Future<void> setDefault(int id) async {
    await _db
        .from(_table)
        .update({'is_default': false})
        .eq('is_default', true);
    await _db
        .from(_table)
        .update({'is_default': true, 'is_active': true})
        .eq('id', id);
    _invalidate();
  }

  /// Supprime un thème personnalisé. Les comptes qui l'avaient choisi
  /// retombent sur le thème par défaut (`ON DELETE SET NULL` côté base).
  static Future<void> delete(int id) async {
    await _db.from(_table).delete().eq('id', id);
    _invalidate();
  }
}
