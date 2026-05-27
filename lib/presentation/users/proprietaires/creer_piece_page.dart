import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_extra_fields/form_builder_extra_fields.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lacoloc_front/data/datasources/pieces.dart';
import 'package:lacoloc_front/data/datasources/storage_service.dart';
import 'package:lacoloc_front/data/models/piece.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

const _nomsSuggeres = [
  'Cuisine',
  'Salon',
  'Salle à manger',
  'Salon / Salle à manger',
  'Entrée',
  'Couloir',
  'Salle de bain',
  "Salle d'eau",
  'Toilettes',
  'WC',
  'Chambre',
  'Bureau',
  'Buanderie',
  'Cellier / Débarras',
  'Dressing',
  'Balcon',
  'Terrasse',
  'Jardin',
  'Véranda',
  'Garage',
  'Cave',
  'Grenier',
  'Local technique',
];

class CreerPiecePage extends StatefulWidget {
  final int immeubleId;
  final PieceModel? existing;

  const CreerPiecePage({super.key, required this.immeubleId, this.existing});

  bool get isEditing => existing != null;

  @override
  State<CreerPiecePage> createState() => _CreerPiecePageState();
}

class _CreerPiecePageState extends State<CreerPiecePage> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _isLoading = false;
  late List<PiecePhoto> _photos;

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.existing?.photos ?? []);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;

    setState(() => _isLoading = true);
    try {
      final m2Raw = values['m2'] as String?;
      final m2 = (m2Raw != null && m2Raw.isNotEmpty)
          ? double.tryParse(m2Raw.replaceAll(',', '.'))
          : null;

      final piece = PieceModel(
        id: widget.existing?.id ?? 0,
        immeubleId: widget.immeubleId,
        nom: (values['nom'] as String).trim(),
        m2: m2,
        description: (values['description'] as String?)?.trim(),
        photos: _photos,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      if (widget.isEditing) {
        await PiecesDatasource.update(widget.existing!.id, piece);
      } else {
        await PiecesDatasource.create(piece);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.isEditing ? 'Modifier la pièce' : 'Nouvelle pièce',
          ),
          leading: const BackButton(),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 560),
              child: FormBuilder(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Nom ──────────────────────────────────────────────
                    _label('NOM DE LA PIÈCE'),
                    FormBuilderTypeAhead<String>(
                      name: 'nom',
                      initialValue: widget.existing?.nom,
                      decoration: const InputDecoration(
                        hintText: 'ex : Cuisine, Salon, Salle de bain…',
                      ),
                      validator: FormBuilderValidators.required(
                        errorText: 'Champ obligatoire',
                      ),
                      itemBuilder: (context, suggestion) => ListTile(
                        dense: true,
                        title: Text(suggestion),
                      ),
                      suggestionsCallback: (pattern) {
                        if (pattern.isEmpty) return _nomsSuggeres;
                        final q = pattern.toLowerCase();
                        return _nomsSuggeres
                            .where((n) => n.toLowerCase().contains(q))
                            .toList();
                      },
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Metragem ─────────────────────────────────────────
                    _label('SUPERFICIE (m²)'),
                    FormBuilderTextField(
                      name: 'm2',
                      initialValue: widget.existing?.m2?.toStringAsFixed(0),
                      decoration: const InputDecoration(hintText: 'ex : 18'),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Description ──────────────────────────────────────
                    _label('DESCRIPTION'),
                    FormBuilderTextField(
                      name: 'description',
                      initialValue: widget.existing?.description,
                      decoration: const InputDecoration(
                        hintText:
                            'Décrivez cette pièce (équipements, état, etc.)',
                        alignLabelWithHint: true,
                      ),
                      minLines: 3,
                      maxLines: 6,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Photos ───────────────────────────────────────────
                    _label('PHOTOS'),
                    _PiecePhotoPickerField(
                      immeubleId: widget.immeubleId,
                      photos: _photos,
                      onChanged: (photos) =>
                          setState(() => _photos = photos),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Bouton soumettre ─────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.onPrimary,
                                ),
                              )
                            : Text(
                                widget.isEditing
                                    ? 'Enregistrer les modifications'
                                    : 'Ajouter la pièce',
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: Text(
      text,
      style: AppTypography.labelSm.copyWith(
        color: AppColors.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _PiecePhotoPickerField extends StatefulWidget {
  final int immeubleId;
  final List<PiecePhoto> photos;
  final void Function(List<PiecePhoto>) onChanged;

  const _PiecePhotoPickerField({
    required this.immeubleId,
    required this.photos,
    required this.onChanged,
  });

  @override
  State<_PiecePhotoPickerField> createState() => _PiecePhotoPickerFieldState();
}

class _PiecePhotoPickerFieldState extends State<_PiecePhotoPickerField> {
  final _picker = ImagePicker();
  late List<PiecePhoto> _photos;
  bool _uploading = false;
  String? _errorMsg;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _photos = List.from(widget.photos);
  }

  Future<void> _onAddTap() async {
    setState(() => _errorMsg = null);
    if (_isMobile) {
      await _showSourceSheet();
    } else {
      final images = await _picker.pickMultiImage();
      await _uploadAll(images);
    }
  }

  Future<void> _showSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXxl),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.outlineVariant,
                borderRadius: AppRadius.borderFull,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir depuis la galerie'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == ImageSource.camera) {
      final img = await _picker.pickImage(source: ImageSource.camera);
      if (img != null) await _uploadAll([img]);
    } else {
      final imgs = await _picker.pickMultiImage();
      await _uploadAll(imgs);
    }
  }

  Future<void> _uploadAll(List<XFile> images) async {
    if (images.isEmpty) return;
    setState(() => _uploading = true);
    try {
      for (final image in images) {
        final bytes = await image.readAsBytes();
        final url = await StorageService.upload(
          bytes: bytes,
          filename: image.name,
          folder: 'pieces',
        );
        if (!mounted) return;
        setState(() => _photos.add(PiecePhoto(url: url)));
        widget.onChanged(List.from(_photos));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Erreur de téléversement : $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _remove(int index) {
    final url = _photos[index].url;
    setState(() => _photos.removeAt(index));
    widget.onChanged(List.from(_photos));
    StorageService.delete(url).ignore();
  }

  void _toggleAnnonce(int index) {
    setState(() {
      _photos[index] = _photos[index].copyWith(
        dansAnnonce: !_photos[index].dansAnnonce,
      );
    });
    widget.onChanged(List.from(_photos));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Dica de estrela (sempre visível, antes do botão)
        Row(
          children: [
            Icon(
              Icons.star_rounded,
              size: 16,
              color: AppColors.secondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Appuyez sur ★ pour afficher la photo dans l\'annonce de l\'immeuble',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        // Botão adicionar
        OutlinedButton.icon(
          onPressed: _uploading ? null : _onAddTap,
          icon: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(
            _uploading ? 'Téléversement…' : 'Ajouter des photos',
          ),
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _errorMsg!,
            style: AppTypography.labelSm.copyWith(color: AppColors.error),
          ),
        ],

        if (_photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List.generate(
              _photos.length,
              (i) => _PieceThumbnail(
                photo: _photos[i],
                onRemove: () => _remove(i),
                onToggleAnnonce: () => _toggleAnnonce(i),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _PieceThumbnail extends StatelessWidget {
  final PiecePhoto photo;
  final VoidCallback onRemove;
  final VoidCallback onToggleAnnonce;

  const _PieceThumbnail({
    required this.photo,
    required this.onRemove,
    required this.onToggleAnnonce,
  });

  @override
  Widget build(BuildContext context) {
    final isMarked = photo.dansAnnonce;
    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: isMarked ? AppColors.secondary : AppColors.outlineVariant,
              width: isMarked ? 2 : 1,
            ),
            color: AppColors.surfaceContainerLow,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderMd,
            child: CachedNetworkImage(
              imageUrl: photo.url,
              fit: BoxFit.cover,
              placeholder: (_, _) => const SizedBox.shrink(),
              errorWidget: (_, _, _) => const Icon(
                Icons.broken_image_outlined,
                color: AppColors.outline,
              ),
            ),
          ),
        ),
        // Botão remover (canto superior direito)
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
        // Estrela: toggle dans l'annonce (canto inferior esquerdo)
        Positioned(
          bottom: 4,
          left: 4,
          child: GestureDetector(
            onTap: onToggleAnnonce,
            child: Icon(
              isMarked ? Icons.star_rounded : Icons.star_border_rounded,
              size: 22,
              color: isMarked ? AppColors.secondary : Colors.white,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 6),
              ],
            ),
          ),
        ),
        // Badge "Annonce" quando marcada
        if (isMarked)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: AppRadius.borderFull,
              ),
              child: Text(
                'Annonce',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSecondary,
                  fontSize: 9,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
