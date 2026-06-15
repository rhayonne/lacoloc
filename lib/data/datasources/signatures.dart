import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/storage_service.dart';
import 'package:flutter/foundation.dart';

/// Gestion des signatures sauvegardées par utilisateur (table `user_signatures`).
class SignaturesDatasource {
  SignaturesDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'user_signatures';

  /// Retourne l'URL de la signature sauvegardée de l'utilisateur courant, ou null.
  static Future<String?> getSavedUrl() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return null;
    final rows = await _db
        .from(_table)
        .select('signature_url')
        .eq('user_id', uid)
        .limit(1);
    if (rows.isEmpty) return null;
    return rows.first['signature_url'] as String?;
  }

  /// Enregistre (upsert) la signature de l'utilisateur courant.
  /// Supprime l'ancienne image du Storage avant de sauvegarder la nouvelle.
  static Future<void> saveUrl(String url) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    // Supprimer l'ancienne si elle existe
    final old = await getSavedUrl();
    if (old != null && old != url) {
      try {
        await StorageService.delete(old);
      } catch (_) {}
    }
    await _db.from(_table).upsert(
      {'user_id': uid, 'signature_url': url, 'updated_at': DateTime.now().toIso8601String()},
      onConflict: 'user_id',
    );
  }

  /// Supprime la signature sauvegardée (Storage + ligne DB).
  static Future<void> deleteSignature() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final old = await getSavedUrl();
    if (old != null) {
      try { await StorageService.delete(old); } catch (_) {}
    }
    await _db.from(_table).delete().eq('user_id', uid);
  }

  /// Upload des bytes PNG de la signature et retourne l'URL publique.
  static Future<String> uploadPng(Uint8List bytes) {
    return StorageService.upload(
      bytes: bytes,
      filename: 'signature.png',
      folder: 'signatures',
    );
  }
}
