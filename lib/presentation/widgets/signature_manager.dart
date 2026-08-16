import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:habitafrance/data/datasources/signatures.dart';
import 'package:habitafrance/data/datasources/storage_service.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/private_image.dart';
import 'package:habitafrance/presentation/widgets/signature_image_edit.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/utils/signature_pad.dart';

/// Section **« Ma signature »** (inline, réutilisable) : gère les deux
/// signatures possibles de l'utilisateur — **manuscrite** (dessinée, gestuelle)
/// et **image** (fichier importé). **Au plus une par type.**
///
/// La liste n'affiche que les signatures **existantes**. Un unique bouton
/// **« Ajouter une signature »** ouvre un **menu déroulant** proposant
/// uniquement le(s) type(s) manquant(s) : *gestuelle* (ouvre l'écran de
/// signature gestuelle — tactile ou souris) et/ou *importer une image* (galerie).
/// Le bouton disparaît quand les **deux** types existent.
///
/// Une signature créée peut ensuite être modifiée (pivoter / rogner / refaire /
/// remplacer). L'une des deux est **principale** (encadrée en bleu).
class SignatureManagerSection extends StatefulWidget {
  const SignatureManagerSection({super.key});

  @override
  State<SignatureManagerSection> createState() =>
      _SignatureManagerSectionState();
}

class _SignatureManagerSectionState extends State<SignatureManagerSection> {
  late Future<List<SignatureEntry>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final f = SignaturesDatasource.listByUser();
    setState(() { _future = f; });
  }

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

  /// Ajoute une signature **gestuelle** : ouvre l'écran de dessin puis enregistre.
  Future<void> _addDraw() async {
    final bytes = await showDrawSignatureDialog(context);
    if (bytes == null || !mounted) return;
    await _run(() async {
      final ref = await SignaturesDatasource.uploadPng(bytes);
      await SignaturesDatasource.saveForKind(
          kind: SignatureKind.draw, ref: ref);
      _reload();
    });
  }

  /// Ajoute une signature **image** : sélection depuis la galerie puis upload.
  Future<void> _addImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 90);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    await _run(() async {
      final ref = await SignaturesDatasource.uploadPng(bytes);
      await SignaturesDatasource.saveForKind(
          kind: SignatureKind.image, ref: ref);
      _reload();
    });
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

        // Types encore manquants (proposés dans le menu « Ajouter »).
        final missing = <SignatureKind>[
          if (byKind(SignatureKind.draw) == null) SignatureKind.draw,
          if (byKind(SignatureKind.image) == null) SignatureKind.image,
        ];

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

            // Liste des signatures existantes uniquement.
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Text(
                  'Aucune signature enregistrée pour le moment.',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              )
            else
              for (final entry in list) ...[
                _SignatureSlot(entry: entry, onChanged: _reload),
                const SizedBox(height: AppSpacing.lg),
              ],

            // Bouton « Ajouter » : visible tant qu'un type manque.
            if (missing.isNotEmpty)
              _AddSignatureButton(
                missing: missing,
                busy: _busy,
                onDraw: _addDraw,
                onImage: _addImage,
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bouton « Ajouter une signature » + menu déroulant des types manquants

class _AddSignatureButton extends StatelessWidget {
  final List<SignatureKind> missing;
  final bool busy;
  final Future<void> Function() onDraw;
  final Future<void> Function() onImage;

  const _AddSignatureButton({
    required this.missing,
    required this.busy,
    required this.onDraw,
    required this.onImage,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      builder: (context, controller, _) => AppButton.primary(
        size: AppButtonSize.compact,
        fullWidth: true,
        icon: Icons.add,
        label: 'Ajouter une signature',
        onPressed: busy
            ? null
            : () => controller.isOpen ? controller.close() : controller.open(),
      ),
      menuChildren: [
        if (missing.contains(SignatureKind.draw))
          MenuItemButton(
            leadingIcon: const Icon(Icons.draw_outlined),
            onPressed: onDraw,
            child: const Text('Signature gestuelle'),
          ),
        if (missing.contains(SignatureKind.image))
          MenuItemButton(
            leadingIcon: const Icon(Icons.image_outlined),
            onPressed: onImage,
            child: const Text('Importer une image'),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Un emplacement rempli (draw ou image)

class _SignatureSlot extends StatefulWidget {
  final SignatureEntry entry;
  final VoidCallback onChanged;

  const _SignatureSlot({
    required this.entry,
    required this.onChanged,
  });

  @override
  State<_SignatureSlot> createState() => _SignatureSlotState();
}

class _SignatureSlotState extends State<_SignatureSlot> {
  bool _busy = false;

  SignatureKind get _kind => widget.entry.kind;
  bool get _isPrincipal => widget.entry.isPrincipal;

  IconData get _icon =>
      _kind == SignatureKind.draw ? Icons.draw_outlined : Icons.image_outlined;

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

  Future<void> _importImage({bool asPrincipal = false}) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
        source: ImageSource.gallery, imageQuality: 90);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    await _run(() async {
      final ref = await SignaturesDatasource.uploadPng(bytes);
      await SignaturesDatasource.saveForKind(
          kind: SignatureKind.image, ref: ref, asPrincipal: asPrincipal);
      widget.onChanged();
    });
  }

  Future<void> _setPrincipal() async {
    if (_isPrincipal) return;
    await _run(() async {
      await SignaturesDatasource.setPrincipal(_kind);
      widget.onChanged();
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer la signature'),
        content: Text('Supprimer votre ${_kind.label.toLowerCase()} ? '
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
      await SignaturesDatasource.deleteByKind(_kind);
      widget.onChanged();
    });
  }

  Future<void> _edit() async {
    final action = await showSignatureEditSheet(
      context,
      isImage: _kind == SignatureKind.image,
    );
    if (action == null || !mounted) return;

    switch (action) {
      case SignatureEditAction.rotateLeft:
        await _transform((b) => rotateSignatureBytes(b, -90));
      case SignatureEditAction.rotateRight:
        await _transform((b) => rotateSignatureBytes(b, 90));
      case SignatureEditAction.crop:
        await _cropCurrent();
      case SignatureEditAction.replace:
        await _replace();
    }
  }

  /// Télécharge les bytes courants, applique [fn], ré-upload (même type).
  Future<void> _transform(Future<Uint8List> Function(Uint8List) fn) async {
    final ref = widget.entry.ref;
    await _run(() async {
      final bytes = await StorageService.downloadBytes(ref);
      if (bytes == null) return;
      final out = await fn(bytes);
      final newRef = await SignaturesDatasource.uploadPng(out);
      await SignaturesDatasource.saveForKind(
          kind: _kind, ref: newRef, asPrincipal: _isPrincipal);
      widget.onChanged();
    });
  }

  Future<void> _cropCurrent() async {
    final ref = widget.entry.ref;
    final bytes = await StorageService.downloadBytes(ref);
    if (bytes == null || !mounted) return;
    final cropped = await showSignatureCropDialog(context, bytes);
    if (cropped == null) return;
    await _run(() async {
      final newRef = await SignaturesDatasource.uploadPng(cropped);
      await SignaturesDatasource.saveForKind(
          kind: _kind, ref: newRef, asPrincipal: _isPrincipal);
      widget.onChanged();
    });
  }

  /// Remplacer : avertit que la signature actuelle sera perdue, puis
  /// (image → galerie ; draw → écran de signature gestuelle).
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
    if (_kind == SignatureKind.image) {
      await _importImage(asPrincipal: _isPrincipal);
    } else {
      final bytes = await showDrawSignatureDialog(context);
      if (bytes == null || !mounted) return;
      await _run(() async {
        final newRef = await SignaturesDatasource.uploadPng(bytes);
        await SignaturesDatasource.saveForKind(
            kind: SignatureKind.draw, ref: newRef, asPrincipal: _isPrincipal);
        widget.onChanged();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Emplacement principal = encadré en bleu (bord + ombre bleus).
    final borderColor =
        _isPrincipal ? AppColors.primary : AppColors.outlineVariant;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: borderColor, width: _isPrincipal ? 2 : 1),
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
              Text(_kind.label, style: AppTypography.titleLs),
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
          _filled(context),
        ],
      ),
    );
  }

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
          child: PrivateImage(ref: widget.entry.ref, fit: BoxFit.contain),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Écran de signature gestuelle (dessin — tactile ou souris)

/// Largeur en-dessous de laquelle l'écran de signature gestuelle s'ouvre en
/// **bottom sheet plein écran** plutôt qu'en `Dialog` centré (même règle que
/// `showSignatureDialog` dans `utils/signature_pad.dart` — voir le
/// commentaire là-bas pour le choix de `MediaQuery` sur cet overlay
/// top-level).
const double _kNarrowSignatureBreakpoint = 600;

/// Ouvre l'écran de **signature gestuelle**. Le pad fonctionne au doigt
/// (tactile) comme à la souris. Retourne les bytes PNG dessinés, ou null si
/// l'utilisateur annule.
Future<Uint8List?> showDrawSignatureDialog(BuildContext context) {
  final isNarrow =
      MediaQuery.sizeOf(context).width < _kNarrowSignatureBreakpoint;
  if (isNarrow) {
    return showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DrawSignatureDialog(asSheet: true),
    );
  }
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _DrawSignatureDialog(),
  );
}

class _DrawSignatureDialog extends StatefulWidget {
  /// Rendu en bottom sheet plein écran (mobile étroit) au lieu du `Dialog`
  /// centré (desktop/tablette).
  final bool asSheet;

  const _DrawSignatureDialog({this.asSheet = false});

  @override
  State<_DrawSignatureDialog> createState() => _DrawSignatureDialogState();
}

class _DrawSignatureDialogState extends State<_DrawSignatureDialog> {
  final _padKey = GlobalKey<SignaturePadState>();
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final bytes = await _padKey.currentState?.exportPng();
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez dessiner votre signature.')),
      );
      return;
    }
    Navigator.pop(context, bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.asSheet) return _buildSheet(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: _content(context, padHeight: 200),
        ),
      ),
    );
  }

  /// Bottom sheet plein écran (mobile étroit) : gagne toute la largeur pour
  /// le tracé et une bonne part de la hauteur disponible.
  Widget _buildSheet(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final padHeight = (size.height * 0.45).clamp(260.0, 420.0);
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: size.height * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.outlineVariant,
                      borderRadius: AppRadius.borderFull,
                    ),
                  ),
                ),
                _content(context, padHeight: padHeight),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Contenu partagé entre le `Dialog` (desktop) et la bottom sheet
  /// (mobile) ; seule la hauteur du pad de dessin change.
  Widget _content(BuildContext context, {required double padHeight}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Signature gestuelle', style: AppTypography.titleLg),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Dessinez votre signature ci-dessous (au doigt ou à la souris).',
          style:
              AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(height: padHeight, child: SignaturePad(key: _padKey)),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () => _padKey.currentState?.clear(),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Effacer'),
            ),
            const Spacer(),
            AppButton.cancel(
              size: AppButtonSize.compact,
              label: 'Annuler',
              onPressed: _busy ? null : () => Navigator.pop(context),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton.save(
              size: AppButtonSize.compact,
              label: 'Enregistrer',
              isBusy: _busy,
              onPressed: _busy ? null : _save,
            ),
          ],
        ),
      ],
    );
  }
}

