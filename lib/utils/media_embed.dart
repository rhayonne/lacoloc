import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_radius.dart';

import 'youtube_embed_stub.dart'
    if (dart.library.js_interop) 'youtube_embed_web.dart';

/// Types de média acceptés pour un message.
const kMediaImage = 'image';
const kMediaYoutube = 'youtube';

/// Extrait un identifiant YouTube **valide** (exactement 11 caractères) d'une
/// URL (watch, youtu.be, embed, shorts) ou d'un id brut. Retourne `null` si
/// l'entrée n'est pas reconnue. Sert de **garde anti-injection** : seul un id
/// alphanumérique est ensuite injecté dans l'iframe.
String? parseYoutubeId(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(s)) return s;
  final patterns = <RegExp>[
    RegExp(r'youtu\.be/([A-Za-z0-9_-]{11})'),
    RegExp(r'[?&]v=([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/embed/([A-Za-z0-9_-]{11})'),
    RegExp(r'youtube\.com/shorts/([A-Za-z0-9_-]{11})'),
  ];
  for (final p in patterns) {
    final m = p.firstMatch(s);
    if (m != null) return m.group(1);
  }
  return null;
}

/// Valide une URL http(s) (pour les images). Empêche les schémas exotiques
/// (`javascript:`, `data:`…).
bool isHttpUrl(String s) {
  final u = Uri.tryParse(s.trim());
  return u != null &&
      (u.scheme == 'http' || u.scheme == 'https') &&
      u.host.isNotEmpty;
}

/// Affiche le média d'un message : image (http/https) ou vidéo YouTube intégrée
/// (iframe sur le web, miniature cliquable ailleurs). Rendu sûr : URL d'image
/// validée, id YouTube validé.
class MessageMediaView extends StatelessWidget {
  final String? mediaType;
  final String? mediaUrl;
  final double height;

  const MessageMediaView({
    super.key,
    required this.mediaType,
    required this.mediaUrl,
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    final url = mediaUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();

    if (mediaType == kMediaImage && isHttpUrl(url)) {
      return ClipRRect(
        borderRadius: AppRadius.borderMd,
        child: Image.network(
          url,
          height: height,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }

    if (mediaType == kMediaYoutube) {
      final id = parseYoutubeId(url);
      if (id != null) {
        return ClipRRect(
          borderRadius: AppRadius.borderMd,
          child: buildYoutubeEmbed(id, height: height),
        );
      }
    }

    return const SizedBox.shrink();
  }
}
