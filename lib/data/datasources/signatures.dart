import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/datasources/storage_service.dart';
import 'package:flutter/foundation.dart';

/// Type d'une signature enregistrée : au plus **une par type** et par
/// utilisateur — une **manuscrite** (dessinée) et une **image** (fichier
/// importé). L'une des deux est marquée **principale** (utilisée par défaut).
enum SignatureKind {
  draw,
  image;

  String get code => name; // 'draw' | 'image'

  static SignatureKind fromCode(String? c) =>
      c == 'image' ? SignatureKind.image : SignatureKind.draw;

  String get label =>
      this == SignatureKind.draw ? 'Signature manuscrite' : 'Image importée';
}

/// Une signature enregistrée de l'utilisateur.
class SignatureEntry {
  final int id;
  final SignatureKind kind;

  /// Référence de stockage (`doc:...` privé) ou URL.
  final String ref;
  final bool isPrincipal;
  final DateTime? updatedAt;

  const SignatureEntry({
    required this.id,
    required this.kind,
    required this.ref,
    required this.isPrincipal,
    this.updatedAt,
  });

  factory SignatureEntry.fromMap(Map<String, dynamic> m) => SignatureEntry(
        id: (m['id'] as num).toInt(),
        kind: SignatureKind.fromCode(m['kind'] as String?),
        ref: m['signature_url'] as String,
        isPrincipal: (m['is_principal'] as bool?) ?? false,
        updatedAt: m['updated_at'] != null
            ? DateTime.tryParse(m['updated_at'] as String)
            : null,
      );
}

/// Gestion des signatures sauvegardées par utilisateur (table `user_signatures`).
///
/// Modèle : jusqu'à **deux** lignes par utilisateur — `kind = draw` et
/// `kind = image` — dont **une principale** (`is_principal`). La RLS reste
/// « propriétaire uniquement » (`auth.uid() = user_id`).
class SignaturesDatasource {
  SignaturesDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'user_signatures';
  static const _select = 'id, signature_url, kind, is_principal, updated_at';

  // ── Lecture ────────────────────────────────────────────────────────────────

  /// Toutes les signatures de l'utilisateur courant (0 à 2).
  static Future<List<SignatureEntry>> listByUser() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return [];
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('user_id', uid)
        .order('kind');
    return rows.map(SignatureEntry.fromMap).toList();
  }

  /// La signature d'un type donné, ou null.
  static Future<SignatureEntry?> getByKind(SignatureKind kind) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return null;
    final rows = await _db
        .from(_table)
        .select(_select)
        .eq('user_id', uid)
        .eq('kind', kind.code)
        .limit(1);
    if (rows.isEmpty) return null;
    return SignatureEntry.fromMap(rows.first);
  }

  /// Référence de la signature **principale** (sinon n'importe laquelle), ou
  /// null. Utilisée par les flux de signature (EDL / bail) et le PDF.
  static Future<String?> getPrincipalRef() async {
    final list = await listByUser();
    if (list.isEmpty) return null;
    final principal = list.where((s) => s.isPrincipal);
    return (principal.isNotEmpty ? principal.first : list.first).ref;
  }

  /// Alias historique (renvoie désormais la signature **principale**).
  static Future<String?> getSavedUrl() => getPrincipalRef();

  // ── Écriture ─────────────────────────────────────────────────────────────

  /// Enregistre/remplace la signature d'un **type** (`kind`). Supprime l'ancienne
  /// image de ce type du Storage. Devient principale si [asPrincipal] est vrai
  /// ou s'il n'existe encore aucune principale.
  static Future<void> saveForKind({
    required SignatureKind kind,
    required String ref,
    bool asPrincipal = false,
  }) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;

    // Supprimer l'ancienne image de CE type (si différente).
    final existing = await getByKind(kind);
    if (existing != null && existing.ref != ref) {
      try {
        await StorageService.delete(existing.ref);
      } catch (_) {}
    }

    await _db.from(_table).upsert(
      {
        'user_id': uid,
        'kind': kind.code,
        'signature_url': ref,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,kind',
    );

    // Garantit qu'une principale existe toujours.
    final all = await listByUser();
    final hasPrincipal = all.any((s) => s.isPrincipal);
    if (asPrincipal || !hasPrincipal) {
      await setPrincipal(kind);
    }
  }

  /// Marque la signature [kind] comme **principale** (l'unique principale).
  static Future<void> setPrincipal(SignatureKind kind) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    // Démarque d'abord (l'index unique partiel n'autorise qu'une principale).
    await _db.from(_table).update({'is_principal': false}).eq('user_id', uid);
    await _db
        .from(_table)
        .update({'is_principal': true})
        .eq('user_id', uid)
        .eq('kind', kind.code);
  }

  /// Supprime la signature d'un **type** (Storage + ligne). Si c'était la
  /// principale et qu'il en reste une autre, promeut l'autre en principale.
  static Future<void> deleteByKind(SignatureKind kind) async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final e = await getByKind(kind);
    if (e == null) return;
    try {
      await StorageService.delete(e.ref);
    } catch (_) {}
    await _db
        .from(_table)
        .delete()
        .eq('user_id', uid)
        .eq('kind', kind.code);
    if (e.isPrincipal) {
      final rest = await listByUser();
      if (rest.isNotEmpty) await setPrincipal(rest.first.kind);
    }
  }

  // ── Compat historique ─────────────────────────────────────────────────────

  /// Historique : enregistre une URL comme signature **image** principale.
  static Future<void> saveUrl(String url) =>
      saveForKind(kind: SignatureKind.image, ref: url, asPrincipal: true);

  /// Historique : supprime **toutes** les signatures de l'utilisateur.
  static Future<void> deleteSignature() async {
    final uid = AuthService.currentUser?.id;
    if (uid == null) return;
    final all = await listByUser();
    for (final e in all) {
      try {
        await StorageService.delete(e.ref);
      } catch (_) {}
    }
    await _db.from(_table).delete().eq('user_id', uid);
  }

  // ── Storage ────────────────────────────────────────────────────────────────

  /// Upload des bytes PNG de la signature (bucket privé) et retourne une
  /// référence `doc:` à stocker.
  static Future<String> uploadPng(Uint8List bytes) {
    return StorageService.upload(
      bytes: bytes,
      filename: 'signature.png',
      folder: 'signatures',
    );
  }

  /// Copie la signature [sourceRef] (sauvegardée par l'utilisateur, privée) dans
  /// l'espace de l'EDL `etat_de_lieux/{edlId}/signatures/...` afin qu'elle soit
  /// **lisible par les deux parties** (RLS can_access_edl) — nécessaire pour le
  /// PDF où chaque partie voit la signature de l'autre. [role] = `proprietaire`
  /// ou `locataire`. En cas d'échec, renvoie [sourceRef] tel quel (repli sûr).
  static Future<String> materializeForEdl({
    required int edlId,
    required String role,
    required String sourceRef,
  }) async {
    try {
      final prefix = 'etat_de_lieux/$edlId/';
      if (StorageService.isPrivateRef(sourceRef) &&
          StorageService.pathOfRef(sourceRef).startsWith(prefix)) {
        return sourceRef; // déjà dans l'espace de cet EDL
      }
      final bytes = await StorageService.downloadBytes(sourceRef);
      if (bytes == null) return sourceRef;
      final ts = DateTime.now().millisecondsSinceEpoch;
      return await StorageService.uploadDocument(
        bytes: bytes,
        path: '${prefix}signatures/$role-$ts.png',
        contentType: 'image/png',
      );
    } catch (_) {
      return sourceRef;
    }
  }
}
