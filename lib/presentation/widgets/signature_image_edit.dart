import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Outils **partagés** d'édition d'une signature (bytes PNG) : feuille
/// d'actions « Modifier » (pivoter / rogner / remplacer), rotation et rognage.
///
/// Source unique réutilisée par la section « Ma signature »
/// (`signature_manager.dart`) **et** par le pop-up de signature
/// (`signature_pad.dart`) — pour garantir les mêmes options d'édition partout.

/// Action d'édition proposée dans la feuille « Modifier la signature ».
enum SignatureEditAction { rotateLeft, rotateRight, crop, replace }

/// Ouvre la feuille d'actions « Modifier la signature » (pivoter / rogner /
/// remplacer). [isImage] adapte le libellé du remplacement.
Future<SignatureEditAction?> showSignatureEditSheet(
  BuildContext context, {
  required bool isImage,
}) {
  return showModalBottomSheet<SignatureEditAction>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text('Modifier la signature', style: AppTypography.titleLs),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: const Icon(Icons.rotate_left),
            title: const Text('Pivoter à gauche'),
            onTap: () => Navigator.pop(ctx, SignatureEditAction.rotateLeft),
          ),
          ListTile(
            leading: const Icon(Icons.rotate_right),
            title: const Text('Pivoter à droite'),
            onTap: () => Navigator.pop(ctx, SignatureEditAction.rotateRight),
          ),
          ListTile(
            leading: const Icon(Icons.crop),
            title: const Text('Rogner'),
            onTap: () => Navigator.pop(ctx, SignatureEditAction.crop),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(isImage
                ? 'Remplacer par une autre image'
                : 'Refaire la signature'),
            onTap: () => Navigator.pop(ctx, SignatureEditAction.replace),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    ),
  );
}

/// Rotation des bytes PNG (angle en degrés, +90 = horaire).
Future<Uint8List> rotateSignatureBytes(Uint8List png, int angle) {
  // Décodage/rotation/réencodage PNG hors du thread UI (isolate) pour ne pas
  // bloquer un frame — négligeable ici mais gratuit avec `compute`.
  return compute(_rotatePngInIsolate, (png, angle));
}

/// Exécuté dans un isolate (`compute`) : doit être une fonction de premier
/// niveau prenant un seul argument.
Uint8List _rotatePngInIsolate((Uint8List, int) args) {
  final (png, angle) = args;
  final decoded = img.decodeImage(png);
  if (decoded == null) return png;
  final rotated = img.copyRotate(decoded, angle: angle);
  return Uint8List.fromList(img.encodePng(rotated));
}

/// Ouvre la boîte de rognage et retourne les bytes rognés (null si annulé).
Future<Uint8List?> showSignatureCropDialog(
  BuildContext context,
  Uint8List bytes,
) {
  return showDialog<Uint8List>(
    context: context,
    builder: (_) => _CropDialog(bytes: bytes),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Boîte de rognage (crop_your_image)

class _CropDialog extends StatefulWidget {
  final Uint8List bytes;
  const _CropDialog({required this.bytes});

  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  final _controller = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Text('Rogner la signature', style: AppTypography.titleLs),
                ],
              ),
            ),
            SizedBox(
              height: 340,
              child: Crop(
                image: widget.bytes,
                controller: _controller,
                baseColor: AppColors.surfaceContainerLow,
                maskColor: Colors.black.withValues(alpha: 0.5),
                onCropped: (result) {
                  if (!mounted) return;
                  if (result is CropSuccess) {
                    Navigator.pop(context, result.croppedImage);
                  } else {
                    setState(() => _cropping = false);
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton.cancel(
                    size: AppButtonSize.compact,
                    label: 'Annuler',
                    onPressed:
                        _cropping ? null : () => Navigator.pop(context),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton.save(
                    size: AppButtonSize.compact,
                    icon: Icons.crop,
                    label: 'Rogner',
                    isBusy: _cropping,
                    onPressed: _cropping
                        ? null
                        : () {
                            setState(() => _cropping = true);
                            _controller.crop();
                          },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
