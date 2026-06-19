import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upload/lecture/suppression d'images dans le Storage Supabase.
///
/// Deux buckets :
/// - **`photos`** (public) — contenu non sensible affiché publiquement
///   (photos d'immeubles, de chambres, de pièces de l'annonce). Les URLs
///   publiques sont stables et stockées telles quelles.
/// - **`documents`** (privé) — contenu sensible (signatures, photos d'EDL).
///   On ne stocke PAS une URL publique mais une **référence** `doc:<path>` ;
///   à l'affichage, on génère une **URL signée temporaire** ([resolveUrl]).
///   L'accès est contrôlé par RLS (can_access_edl pour les EDL ; propriétaire
///   du fichier pour les signatures).
///
/// Convention de chemins :
/// - public  : `{folder}/{ownerId}/{timestamp}.{ext}`
/// - EDL     : `etat_de_lieux/{edlId}/{kind}/{ownerId}/{timestamp}.{ext}`
/// - signat. : `signatures/{userId}/{timestamp}.{ext}`
class StorageService {
  StorageService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String publicBucket = 'photos';
  static const String privateBucket = 'documents';

  /// Préfixe d'une référence vers un fichier privé (au lieu d'une URL).
  static const String docPrefix = 'doc:';

  /// Un dossier est « privé » (bucket documents) s'il s'agit d'une signature
  /// ou d'un fichier d'état des lieux.
  static bool _isPrivateFolder(String folder) =>
      folder == 'signatures' || folder.startsWith('etat_de_lieux');

  /// True si [ref] désigne un fichier privé (`doc:<path>`).
  static bool isPrivateRef(String ref) => ref.startsWith(docPrefix);

  /// Extrait le chemin Storage d'une référence privée.
  static String pathOfRef(String ref) =>
      isPrivateRef(ref) ? ref.substring(docPrefix.length) : ref;

  // ── Upload ────────────────────────────────────────────────────────────────

  /// Upload générique. Route automatiquement vers le bon bucket selon [folder].
  /// Retourne soit une **URL publique** (contenu public), soit une **référence**
  /// `doc:<path>` (contenu privé) à stocker en base.
  static Future<String> upload({
    required Uint8List bytes,
    required String filename,
    required String folder,
  }) async {
    final ownerId = AuthService.currentUser!.id;
    final ext = filename.contains('.')
        ? filename.split('.').last.toLowerCase()
        : 'jpg';
    final ts = DateTime.now().millisecondsSinceEpoch;

    if (_isPrivateFolder(folder)) {
      // Privé : on insère l'ownerId juste avant le nom de fichier pour
      // conserver l'edlId (folder index 2) en tête de chemin pour la RLS.
      final path = '$folder/$ownerId/$ts.$ext';
      await _client.storage.from(privateBucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: _mimeType(ext), upsert: false),
          );
      return '$docPrefix$path';
    }

    final path = '$folder/$ownerId/$ts.$ext';
    await _client.storage.from(publicBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _mimeType(ext), upsert: false),
        );
    return _client.storage.from(publicBucket).getPublicUrl(path);
  }

  /// Upload bas niveau vers un chemin explicite du bucket privé. Utilisé pour
  /// copier une signature dans l'espace d'un EDL (`etat_de_lieux/{edlId}/...`)
  /// afin qu'elle soit lisible par les deux parties via can_access_edl.
  /// Retourne une référence `doc:<path>`.
  static Future<String> uploadDocument({
    required Uint8List bytes,
    required String path,
    String contentType = 'image/png',
  }) async {
    await _client.storage.from(privateBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return '$docPrefix$path';
  }

  // ── Lecture ─────────────────────────────────────────────────────────────--

  // Cache mémoire des URLs signées (path → (url, expiration)).
  static final Map<String, ({String url, DateTime expiry})> _signedCache = {};
  static const int _signedTtlSeconds = 3600; // 1 h

  /// Transforme une référence stockée en URL affichable.
  /// - URL publique / héritée → renvoyée telle quelle.
  /// - Référence privée `doc:` → URL signée temporaire (mise en cache).
  static Future<String> resolveUrl(String ref) async {
    if (!isPrivateRef(ref)) return ref;
    final path = pathOfRef(ref);
    final cached = _signedCache[path];
    if (cached != null && cached.expiry.isAfter(DateTime.now())) {
      return cached.url;
    }
    final signed =
        await _client.storage.from(privateBucket).createSignedUrl(path, _signedTtlSeconds);
    _signedCache[path] = (
      url: signed,
      // On renouvelle un peu avant l'expiration réelle.
      expiry: DateTime.now().add(const Duration(seconds: _signedTtlSeconds - 120)),
    );
    return signed;
  }

  /// Télécharge les octets d'un fichier, qu'il soit privé (`doc:`) ou public.
  /// Pour un fichier privé, passe par `download` (RLS) ; sinon par HTTP.
  static Future<Uint8List?> downloadBytes(String ref) async {
    try {
      if (isPrivateRef(ref)) {
        return await _client.storage.from(privateBucket).download(pathOfRef(ref));
      }
      final resp = await http.get(Uri.parse(ref));
      return resp.statusCode == 200 ? resp.bodyBytes : null;
    } catch (_) {
      return null;
    }
  }

  // ── Suppression ─────────────────────────────────────────────────────────--

  static Future<void> delete(String ref) async {
    if (isPrivateRef(ref)) {
      await _client.storage.from(privateBucket).remove([pathOfRef(ref)]);
      _signedCache.remove(pathOfRef(ref));
      return;
    }
    final path = _pathFromPublicUrl(ref);
    if (path == null) return;
    await _client.storage.from(publicBucket).remove([path]);
  }

  // ── Helpers ─────────────────────────────────────────────────────────────--

  static String _mimeType(String ext) => switch (ext) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };

  static String? _pathFromPublicUrl(String url) {
    const marker = '/object/public/$publicBucket/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    return Uri.decodeComponent(url.substring(idx + marker.length));
  }
}
