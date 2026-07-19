import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lacoloc_front/data/datasources/signatures.dart';
import 'package:lacoloc_front/presentation/widgets/private_image.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

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

enum _SignatureTab { dessiner, importer, sauvegardee }

class _SignatureDialogState extends State<_SignatureDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _padKey = GlobalKey<SignaturePadState>();

  // Onglet importer / sauvegardée
  Uint8List? _importedBytes;
  String? _savedUrl; // URL de la signature sauvegardée existante
  bool _loadingSaved = true;
  bool _uploading = false;
  bool _saveAsDefault = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final hasSaved = widget.existingUrl != null;
    _tab = TabController(
      length: 3,
      vsync: this,
      initialIndex: hasSaved ? 2 : 0,
    );
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    try {
      final url = widget.existingUrl ?? await SignaturesDatasource.getSavedUrl();
      if (mounted) setState(() { _savedUrl = url; _loadingSaved = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();
    if (mounted) setState(() => _importedBytes = bytes);
  }

  Future<void> _confirm() async {
    setState(() { _uploading = true; _error = null; });
    try {
      Uint8List? bytes;

      switch (_SignatureTab.values[_tab.index]) {
        case _SignatureTab.dessiner:
          bytes = await _padKey.currentState?.exportPng();
          if (bytes == null) {
            setState(() { _uploading = false; _error = 'Veuillez dessiner votre signature.'; });
            return;
          }
        case _SignatureTab.importer:
          bytes = _importedBytes;
          if (bytes == null) {
            setState(() { _uploading = false; _error = 'Veuillez sélectionner une image.'; });
            return;
          }
        case _SignatureTab.sauvegardee:
          if (_savedUrl == null) {
            setState(() { _uploading = false; _error = 'Aucune signature sauvegardée.'; });
            return;
          }
          // Réutilise l'URL existante sans nouvel upload
          if (mounted) Navigator.pop(context, (url: _savedUrl!, saveAsDefault: false));
          return;
      }

      final url = await SignaturesDatasource.uploadPng(bytes);
      if (_saveAsDefault) await SignaturesDatasource.saveUrl(url);
      if (mounted) Navigator.pop(context, (url: url, saveAsDefault: _saveAsDefault));
    } catch (e) {
      if (mounted) setState(() { _uploading = false; _error = 'Erreur : $e'; });
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
              TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: 'Dessiner'),
                  Tab(text: 'Importer'),
                  Tab(text: 'Ma signature'),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 220,
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // ── Dessiner ──────────────────────────────────────────
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: SignaturePad(key: _padKey)),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _padKey.currentState?.clear(),
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Effacer'),
                          ),
                        ),
                      ],
                    ),
                    // ── Importer ──────────────────────────────────────────
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_importedBytes != null)
                          Expanded(
                            child: Image.memory(
                              _importedBytes!,
                              fit: BoxFit.contain,
                            ),
                          )
                        else
                          const Text(
                            'Sélectionnez une image de votre signature.',
                            textAlign: TextAlign.center,
                          ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Choisir depuis la galerie'),
                        ),
                      ],
                    ),
                    // ── Signature sauvegardée ─────────────────────────────
                    _loadingSaved
                        ? const Center(child: CircularProgressIndicator())
                        : _savedUrl != null
                            ? Column(
                                children: [
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: AppColors.outlineVariant),
                                        borderRadius: AppRadius.borderMd,
                                        color: Colors.white,
                                      ),
                                      child: PrivateImage(
                                        ref: _savedUrl!,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Center(
                                child: Text(
                                  'Aucune signature sauvegardée.\nDessinez ou importez une signature.',
                                  textAlign: TextAlign.center,
                                  style: AppTypography.bodyMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Option "sauvegarder comme défaut" (visible sauf onglet Ma signature)
              ListenableBuilder(
                listenable: _tab,
                builder: (_, _) => _tab.index != 2
                    ? CheckboxListTile(
                        value: _saveAsDefault,
                        onChanged: (v) => setState(() => _saveAsDefault = v ?? false),
                        title: const Text('Sauvegarder comme ma signature par défaut'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      )
                    : const SizedBox.shrink(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 13)),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _uploading ? null : () => Navigator.pop(context),
                    style: AppTheme.cancelButtonStyle,
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  FilledButton.icon(
                    onPressed: _uploading ? null : _confirm,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Signer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
