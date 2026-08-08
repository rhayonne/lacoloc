import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:habitafrance/data/datasources/signatures.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/signature_image_edit.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Widget de dessin de signature

/// Widget de saisie de signature manuscrite. Renvoie des bytes PNG via [key].
class SignaturePad extends StatefulWidget {
  /// Couleur du tracé (noir par défaut).
  final Color strokeColor;
  final double strokeWidth;

  const SignaturePad({
    super.key,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.5,
  });

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;
  bool _isEmpty = true;

  void clear() => setState(() {
        _strokes.clear();
        _current = null;
        _isEmpty = true;
      });

  bool get isEmpty => _isEmpty;

  /// Exporte la signature en PNG (retourne null si vide).
  Future<Uint8List?> exportPng() async {
    if (_isEmpty) return null;
    return _renderToPng(
      strokes: _strokes,
      color: widget.strokeColor,
      strokeWidth: widget.strokeWidth,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ⚠️ Le fond blanc + la bordure sont sur le Container EXTERIEUR, et les
        // tracés sont peints PAR-DESSUS via CustomPaint. (Auparavant le
        // `child` blanc du CustomPaint recouvrait les tracés → « la signature
        // gestuelle ne marchait pas » : on dessinait sans rien voir.)
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (d) {
            setState(() {
              _current = [d.localPosition];
              _strokes.add(_current!);
              _isEmpty = false;
            });
          },
          onPanUpdate: (d) {
            setState(() => _current?.add(d.localPosition));
          },
          onPanEnd: (_) => setState(() => _current = null),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.outlineVariant),
              borderRadius: AppRadius.borderMd,
              color: Colors.white,
            ),
            clipBehavior: Clip.antiAlias,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SignaturePainter(
                strokes: _strokes,
                color: widget.strokeColor,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final Color color;
  final double strokeWidth;

  const _SignaturePainter({
    required this.strokes,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, strokeWidth / 2, paint);
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_SignaturePainter old) => true;
}

/// Rend les tracés dans un nouveau canvas et retourne les bytes PNG.
Future<Uint8List> _renderToPng({
  required List<List<Offset>> strokes,
  required Color color,
  required double strokeWidth,
  int width = 600,
  int height = 200,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  // Fond blanc
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = Colors.white,
  );

  final paint = Paint()
    ..color = color
    ..strokeWidth = strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  for (final stroke in strokes) {
    if (stroke.length == 1) {
      canvas.drawCircle(stroke.first, strokeWidth / 2, paint);
      continue;
    }
    final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
    for (var i = 1; i < stroke.length; i++) {
      path.lineTo(stroke[i].dx, stroke[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog de signature (dessiner / importer / ma signature)

/// Résultat du dialog de signature.
///
/// [url] : URL publique de la signature dans le Storage (déjà uploadée).
/// [saveAsDefault] : l'utilisateur a demandé à sauvegarder comme signature par défaut.
typedef SignatureResult = ({String url, bool saveAsDefault});

/// Ouvre le dialog de saisie de signature et retourne l'URL une fois uploadée.
/// Retourne null si l'utilisateur annule.
Future<SignatureResult?> showSignatureDialog(
  BuildContext context, {
  String? existingUrl,
}) {
  return showDialog<SignatureResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _SignatureDialog(existingUrl: existingUrl),
  );
}

class _SignatureDialog extends StatefulWidget {
  final String? existingUrl;
  const _SignatureDialog({this.existingUrl});

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final _padKey = GlobalKey<SignaturePadState>();

  /// Type choisi via le sélecteur en haut (gestuelle / image). Remplace les
  /// anciens onglets qui défilaient latéralement (le défilement volait les
  /// gestes horizontaux du tracé → la signature gestuelle ne marchait pas).
  SignatureKind _kind = SignatureKind.draw;

  /// Image importée (mode image), éventuellement éditée (pivotée / rognée).
  Uint8List? _importedBytes;

  bool _busy = false;
  String? _error;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    if (mounted) setState(() => _importedBytes = bytes);
  }

  /// « Modifier l'image » : mêmes options que le menu « Ma signature »
  /// (pivoter / rogner / remplacer), appliquées aux bytes en mémoire.
  Future<void> _editImage() async {
    if (_importedBytes == null) return;
    final action = await showSignatureEditSheet(context, isImage: true);
    if (action == null || !mounted) return;
    switch (action) {
      case SignatureEditAction.rotateLeft:
        final out = await rotateSignatureBytes(_importedBytes!, -90);
        if (mounted) setState(() => _importedBytes = out);
      case SignatureEditAction.rotateRight:
        final out = await rotateSignatureBytes(_importedBytes!, 90);
        if (mounted) setState(() => _importedBytes = out);
      case SignatureEditAction.crop:
        final out = await showSignatureCropDialog(context, _importedBytes!);
        if (out != null && mounted) setState(() => _importedBytes = out);
      case SignatureEditAction.replace:
        await _pickImage();
    }
  }

  /// Règle métier : **une seule** signature par type. Demande confirmation
  /// avant d'écraser une signature existante du même type.
  Future<bool> _confirmReplace() async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplacer la signature'),
        content: Text('Vous avez déjà une ${_kind.label.toLowerCase()}. '
            'Elle sera remplacée par la nouvelle. Continuer ?'),
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
    return res ?? false;
  }

  Future<void> _confirm() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Uint8List? bytes;
      if (_kind == SignatureKind.draw) {
        bytes = await _padKey.currentState?.exportPng();
        if (bytes == null) {
          setState(() {
            _busy = false;
            _error = 'Veuillez dessiner votre signature.';
          });
          return;
        }
      } else {
        bytes = _importedBytes;
        if (bytes == null) {
          setState(() {
            _busy = false;
            _error = 'Veuillez sélectionner une image.';
          });
          return;
        }
      }

      // Une seule signature par type → prévenir avant de remplacer.
      final existing = await SignaturesDatasource.getByKind(_kind);
      if (!mounted) return;
      if (existing != null) {
        final ok = await _confirmReplace();
        if (!ok) {
          if (mounted) setState(() => _busy = false);
          return;
        }
      }

      final ref = await SignaturesDatasource.uploadPng(bytes);
      await SignaturesDatasource.saveForKind(kind: _kind, ref: ref);
      if (mounted) Navigator.pop(context, (url: ref, saveAsDefault: true));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Erreur : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Signer', style: AppTypography.titleLg),
              const SizedBox(height: AppSpacing.md),
              // Sélecteur de type en haut (ne défile pas → gestuel fiable).
              Center(
                child: SegmentedButton<SignatureKind>(
                  segments: const [
                    ButtonSegment(
                      value: SignatureKind.draw,
                      icon: Icon(Icons.draw_outlined),
                      label: Text('Gestuelle'),
                    ),
                    ButtonSegment(
                      value: SignatureKind.image,
                      icon: Icon(Icons.image_outlined),
                      label: Text('Image'),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: _busy
                      ? null
                      : (s) => setState(() {
                            _kind = s.first;
                            _error = null;
                          }),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 200,
                child:
                    _kind == SignatureKind.draw ? _drawArea() : _imageArea(),
              ),
              // « Modifier l'image » sous l'aperçu (mode image, image choisie).
              if (_kind == SignatureKind.image && _importedBytes != null) ...[
                const SizedBox(height: AppSpacing.sm),
                AppButton.edit(
                  size: AppButtonSize.compact,
                  fullWidth: true,
                  icon: Icons.tune,
                  label: "Modifier l'image",
                  onPressed: _busy ? null : _editImage,
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
                    onPressed: _busy ? null : _confirm,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: SignaturePad(key: _padKey)),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _busy ? null : () => _padKey.currentState?.clear(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Effacer'),
          ),
        ),
      ],
    );
  }

  Widget _imageArea() {
    if (_importedBytes == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined,
                size: 40, color: AppColors.onSurfaceVariant),
            const SizedBox(height: AppSpacing.sm),
            Text('Aucune image sélectionnée',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            AppButton.primary(
              size: AppButtonSize.compact,
              icon: Icons.photo_library_outlined,
              label: 'Sélectionner une image',
              onPressed: _busy ? null : _pickImage,
            ),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.outlineVariant),
        borderRadius: AppRadius.borderMd,
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.memory(_importedBytes!, fit: BoxFit.contain),
    );
  }
}
