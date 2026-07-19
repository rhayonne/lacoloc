import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:lacoloc_front/data/datasources/signatures.dart';
import 'package:lacoloc_front/data/datasources/storage_service.dart';
import 'package:lacoloc_front/presentation/widgets/app_button.dart';
import 'package:lacoloc_front/presentation/widgets/private_image.dart';
import 'package:lacoloc_front/theme/app_button_sizes.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/signature_pad.dart';

/// Section **« Ma signature »** (inline, réutilisable) : gère les deux
/// signatures possibles de l'utilisateur — **manuscrite** (dessinée) et
/// **image** (fichier importé). Chaque emplacement se crée sur place ; l'une
/// des deux est **principale** (encadrée en bleu). L'édition (pivoter / rogner /
/// remplacer) se fait via une boîte de dialogue, avec avertissement avant de
/// remplacer.
///
/// Remplace l'ancien parcours « bouton → popup Signer » sur les écrans de
/// réglages (Documentation / profil locataire).
class SignatureManagerSection extends StatefulWidget {
  const SignatureManagerSection({super.key});

  @override
  State<SignatureManagerSection> createState() =>
      _SignatureManagerSectionState();
}

class _SignatureManagerSectionState extends State<SignatureManagerSection> {
  late Future<List<SignatureEntry>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final f = SignaturesDatasource.listByUser();
    setState(() => _future = f);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SignatureEntry>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final list = snap.data ?? const <SignatureEntry>[];
        SignatureEntry? byKind(SignatureKind k) =>
            list.where((s) => s.kind == k).firstOrNull;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vous pouvez enregistrer une signature manuscrite et/ou une '
              'image. Cochez « principale » celle utilisée par défaut sur vos '
              'documents.',
              style: AppTypography.bodyMd
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),
            _SignatureSlot(
              kind: SignatureKind.draw,
              entry: byKind(SignatureKind.draw),
              onChanged: _reload,
            ),
            const SizedBox(height: AppSpacing.lg),
            _SignatureSlot(
              kind: SignatureKind.image,
              entry: byKind(SignatureKind.image),
              onChanged: _reload,
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Un emplacement (draw ou image)

class _SignatureSlot extends StatefulWidget {
  final SignatureKind kind;
  final SignatureEntry? entry;
  final VoidCallback onChanged;

  const _SignatureSlot({
    required this.kind,
    required this.entry,
    required this.onChanged,
  });

  @override
  State<_SignatureSlot> createState() => _SignatureSlotState();
}

class _SignatureSlotState extends State<_SignatureSlot> {
  final _padKey = GlobalKey<SignaturePadState>();
  bool _editingDraw = false; // pad de dessin affiché (création / remplacement)
  bool _busy = false;

  bool get _isPrincipal => widget.entry?.isPrincipal ?? false;

  IconData get _icon => widget.kind == SignatureKind.draw
      ? Icons.draw_outlined
      : Icons.image_outlined;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveDrawing() async {
    final bytes = await _padKey.currentState?.exportPng();
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez dessiner votre signature.')),
        );
      }
      return;
    }
    await _run(() async {
      final ref = await SignaturesDatasource.uploadPng(bytes);
      await SignaturesDatasource.saveForKind(
          kind: SignatureKind.draw, ref: ref);
      _editingDraw = false;
      widget.onChanged();
    });
  }

  Future<void> _importImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 90);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    await _run(() async {
      final ref = await SignaturesDatasource.uploadPng(bytes);
      await SignaturesDatasource.saveForKind(
          kind: SignatureKind.image, ref: ref);
      widget.onChanged();
    });
  }

  Future<void> _setPrincipal() async {
    if (_isPrincipal) return;
    await _run(() async {
      await SignaturesDatasource.setPrincipal(widget.kind);
      widget.onChanged();
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la signature'),
        content: Text('Supprimer votre ${widget.kind.label.toLowerCase()} ? '
            'Cette action est définitive.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await SignaturesDatasource.deleteByKind(widget.kind);
      widget.onChanged();
    });
  }

  Future<void> _edit() async {
    final entry = widget.entry;
    if (entry == null) return;
    final action = await showModalBottomSheet<_EditAction>(
      context: context,
      builder: (ctx) => _EditActionSheet(kind: widget.kind),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case _EditAction.rotateLeft:
        await _transform((b) => _rotate(b, -90));
      case _EditAction.rotateRight:
        await _transform((b) => _rotate(b, 90));
      case _EditAction.crop:
        await _cropCurrent();
      case _EditAction.replace:
        await _replace();
    }
  }

  /// Télécharge les bytes courants, applique [fn], ré-upload (même type).
  Future<void> _transform(Future<Uint8List> Function(Uint8List) fn) async {
    final ref = widget.entry?.ref;
    if (ref == null) return;
    await _run(() async {
      final bytes = await StorageService.downloadBytes(ref);
      if (bytes == null) return;
      final out = await fn(bytes);
      final newRef = await SignaturesDatasource.uploadPng(out);
      await SignaturesDatasource.saveForKind(
          kind: widget.kind, ref: newRef, asPrincipal: _isPrincipal);
      widget.onChanged();
    });
  }

  Future<void> _cropCurrent() async {
    final ref = widget.entry?.ref;
    if (ref == null) return;
    final bytes = await StorageService.downloadBytes(ref);
    if (bytes == null || !mounted) return;
    final cropped = await showDialog<Uint8List>(
      context: context,
      builder: (ctx) => _CropDialog(bytes: bytes),
    );
    if (cropped == null) return;
    await _run(() async {
      final newRef = await SignaturesDatasource.uploadPng(cropped);
      await SignaturesDatasource.saveForKind(
          kind: widget.kind, ref: newRef, asPrincipal: _isPrincipal);
      widget.onChanged();
    });
  }

  /// Remplacer : avertit que la signature actuelle sera perdue, puis
  /// (image → galerie ; draw → pad vierge).
  Future<void> _replace() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplacer la signature'),
        content: const Text(
            'La signature actuelle sera perdue et remplacée. Continuer ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remplacer')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (widget.kind == SignatureKind.image) {
      await _importImage();
    } else {
      setState(() => _editingDraw = true); // pad vierge inline
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.entry != null && !_editingDraw;
    // Emplacement principal = encadré en bleu (bord + ombre bleus).
    final borderColor =
        _isPrincipal ? AppColors.primary : AppColors.outlineVariant;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(
            color: borderColor, width: _isPrincipal ? 2 : 1),
        boxShadow: _isPrincipal
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête de l'emplacement
          Row(
            children: [
              Icon(_icon, size: 20, color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Text(widget.kind.label, style: AppTypography.titleLs),
              const Spacer(),
              if (_isPrincipal)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: AppRadius.borderFull,
                  ),
                  child: Text('Principale',
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onPrimary)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          if (has)
            _filled(context)
          else if (widget.kind == SignatureKind.draw)
            _drawEditor(context)
          else
            _imageEmpty(context),
        ],
      ),
    );
  }

  // ── États ──────────────────────────────────────────────────────────────────

  Widget _filled(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: PrivateImage(ref: widget.entry!.ref, fit: BoxFit.contain),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Case « principale »
        InkWell(
          onTap: _busy ? null : _setPrincipal,
          borderRadius: AppRadius.borderSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Icon(
                  _isPrincipal
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 20,
                  color: _isPrincipal
                      ? AppColors.primary
                      : AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text('Signature principale', style: AppTypography.bodyMd),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton.edit(
                size: AppButtonSize.compact,
                fullWidth: true,
                label: 'Modifier',
                onPressed: _busy ? null : _edit,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton.delete(
                size: AppButtonSize.compact,
                fullWidth: true,
                label: 'Supprimer',
                onPressed: _busy ? null : _delete,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _drawEditor(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Dessinez votre signature dans le cadre.',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(height: 160, child: SignaturePad(key: _padKey)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton.cancel(
                size: AppButtonSize.compact,
                fullWidth: true,
                icon: Icons.refresh,
                label: 'Effacer',
                onPressed:
                    _busy ? null : () => _padKey.currentState?.clear(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: AppButton.save(
                size: AppButtonSize.compact,
                fullWidth: true,
                label: 'Enregistrer',
                isBusy: _busy,
                onPressed: _busy ? null : _saveDrawing,
              ),
            ),
          ],
        ),
        if (_editingDraw) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _editingDraw = false),
              child: const Text('Annuler'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _imageEmpty(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Importez une image de votre signature.',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.sm),
        AppButton.primary(
          size: AppButtonSize.compact,
          fullWidth: true,
          icon: Icons.photo_library_outlined,
          label: 'Importer une image',
          isBusy: _busy,
          onPressed: _busy ? null : _importImage,
        ),
      ],
    );
  }
}

/// Rotation des bytes PNG (angle en degrés, +90 = horaire).
Future<Uint8List> _rotate(Uint8List png, int angle) async {
  final decoded = img.decodeImage(png);
  if (decoded == null) return png;
  final rotated = img.copyRotate(decoded, angle: angle);
  return Uint8List.fromList(img.encodePng(rotated));
}

// ─────────────────────────────────────────────────────────────────────────────
// Feuille d'actions d'édition

enum _EditAction { rotateLeft, rotateRight, crop, replace }

class _EditActionSheet extends StatelessWidget {
  final SignatureKind kind;
  const _EditActionSheet({required this.kind});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Text('Modifier la signature', style: AppTypography.titleLs),
          const SizedBox(height: AppSpacing.sm),
          ListTile(
            leading: const Icon(Icons.rotate_left),
            title: const Text('Pivoter à gauche'),
            onTap: () => Navigator.pop(context, _EditAction.rotateLeft),
          ),
          ListTile(
            leading: const Icon(Icons.rotate_right),
            title: const Text('Pivoter à droite'),
            onTap: () => Navigator.pop(context, _EditAction.rotateRight),
          ),
          ListTile(
            leading: const Icon(Icons.crop),
            title: const Text('Rogner'),
            onTap: () => Navigator.pop(context, _EditAction.crop),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(kind == SignatureKind.image
                ? 'Remplacer par une autre image'
                : 'Refaire la signature'),
            onTap: () => Navigator.pop(context, _EditAction.replace),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
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
