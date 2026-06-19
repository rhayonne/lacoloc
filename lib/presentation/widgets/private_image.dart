import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/storage_service.dart';
import 'package:lacoloc_front/theme/app_colors.dart';

/// Affiche une image à partir d'une **référence** stockée en base, qu'elle
/// soit une URL publique (bucket `photos` / héritée) ou une référence privée
/// `doc:<path>` (bucket `documents`). Pour le privé, génère une URL signée
/// temporaire via [StorageService.resolveUrl] puis l'affiche avec cache.
///
/// Remplace `CachedNetworkImage(imageUrl: ref)` partout où [ref] peut désigner
/// un fichier sensible (signatures, photos d'EDL).
class PrivateImage extends StatelessWidget {
  final String ref;
  final BoxFit fit;
  final double? width;
  final double? height;

  const PrivateImage({
    super.key,
    required this.ref,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    // URL publique : affichage direct (pas de résolution nécessaire).
    if (!StorageService.isPrivateRef(ref)) {
      return CachedNetworkImage(
        imageUrl: ref,
        fit: fit,
        width: width,
        height: height,
        placeholder: (_, _) => const SizedBox.shrink(),
        errorWidget: (_, _, _) =>
            const Icon(Icons.broken_image_outlined, color: AppColors.outline),
      );
    }

    return FutureBuilder<String>(
      future: StorageService.resolveUrl(ref),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        if (snap.hasError || snap.data == null) {
          return const Icon(Icons.broken_image_outlined,
              color: AppColors.outline);
        }
        return CachedNetworkImage(
          imageUrl: snap.data!,
          fit: fit,
          width: width,
          height: height,
          placeholder: (_, _) => const SizedBox.shrink(),
          errorWidget: (_, _, _) =>
              const Icon(Icons.broken_image_outlined, color: AppColors.outline),
        );
      },
    );
  }
}
