import 'package:flutter/foundation.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload e remoção de imagens no bucket `photos` do Supabase Storage.
/// Estrutura de caminhos: {folder}/{owner_id}/{timestamp}.{ext}
class StorageService {
  StorageService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _bucket = 'photos';

  static Future<String> upload({
    required Uint8List bytes,
    required String filename,
    required String folder,
  }) async {
    final ownerId = AuthService.currentUser!.id;
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'jpg';
    final path =
        '$folder/$ownerId/${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _mimeType(ext), upsert: false),
        );

    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  static Future<void> delete(String url) async {
    final path = _pathFromUrl(url);
    if (path == null) return;
    await _client.storage.from(_bucket).remove([path]);
  }

  static String _mimeType(String ext) => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  static String? _pathFromUrl(String url) {
    const marker = '/object/public/$_bucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    return Uri.decodeComponent(url.substring(idx + marker.length));
  }
}
