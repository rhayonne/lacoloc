import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lacoloc_front/data/datasources/storage_service.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Campo de seleção e upload de fotos com miniaturas e seleção de foto principal.
/// - Desktop/Web: abre o explorador de arquivos (múltipla seleção).
/// - Mobile (iOS/Android): pergunta entre câmera e galeria.
/// As fotos são enviadas ao Supabase Storage e as URLs retornadas via [onChanged].
/// A estrela em cada miniatura define/remove a foto principal via [onMainPhotoChanged].
class PhotoPickerField extends StatefulWidget {
  final List<String> initialPhotos;
  final String? initialMainPhoto;
  final void Function(List<String>) onChanged;
  final void Function(String?)? onMainPhotoChanged;

  /// Subpasta dentro do bucket 'photos': 'immeubles' ou 'chambres'.
  final String folder;

  const PhotoPickerField({
    super.key,
    required this.folder,
    required this.onChanged,
    this.onMainPhotoChanged,
    this.initialPhotos = const [],
    this.initialMainPhoto,
  });

  @override
  State<PhotoPickerField> createState() => _PhotoPickerFieldState();
}

class _PhotoPickerFieldState extends State<PhotoPickerField> {
  final _picker = ImagePicker();
  final List<String> _urls = [];
  String? _mainPhoto;
  bool _uploading = false;
  String? _errorMsg;

  bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _urls.addAll(widget.initialPhotos);
    _mainPhoto = widget.initialMainPhoto;
  }

  // ── Interação ──────────────────────────────────────────────────────────────

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
      final image = await _picker.pickImage(source: ImageSource.camera);
      if (image != null) await _uploadAll([image]);
    } else {
      final images = await _picker.pickMultiImage();
      await _uploadAll(images);
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
          folder: widget.folder,
        );
        if (!mounted) return;
        setState(() => _urls.add(url));
        widget.onChanged(List.from(_urls));
      }
    } catch (e) {
      if (mounted) setState(() => _errorMsg = 'Erreur de téléversement : $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _remove(int index) async {
    final url = _urls[index];
    setState(() {
      _urls.removeAt(index);
      if (_mainPhoto == url) {
        _mainPhoto = null;
        widget.onMainPhotoChanged?.call(null);
      }
    });
    widget.onChanged(List.from(_urls));
    StorageService.delete(url).ignore();
  }

  void _toggleMainPhoto(String url) {
    final next = (_mainPhoto == url) ? null : url;
    setState(() => _mainPhoto = next);
    widget.onMainPhotoChanged?.call(next);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _uploading ? null : _onAddTap,
          icon: _uploading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_uploading ? 'Téléversement…' : 'Ajouter des photos'),
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            _errorMsg!,
            style: AppTypography.labelSm.copyWith(color: AppColors.error),
          ),
        ],
        if (_urls.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Appuyez sur ★ pour définir la photo principale',
            style: AppTypography.labelSm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: List.generate(
              _urls.length,
              (i) => _Thumbnail(
                url: _urls[i],
                isMain: _urls[i] == _mainPhoto,
                onRemove: () => _remove(i),
                onToggleMain: () => _toggleMainPhoto(_urls[i]),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  final String url;
  final bool isMain;
  final VoidCallback onRemove;
  final VoidCallback onToggleMain;

  const _Thumbnail({
    required this.url,
    required this.isMain,
    required this.onRemove,
    required this.onToggleMain,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: isMain ? AppColors.primary : AppColors.outlineVariant,
              width: isMain ? 2 : 1,
            ),
            color: AppColors.surfaceContainerLow,
          ),
          child: ClipRRect(
            borderRadius: AppRadius.borderMd,
            child: CachedNetworkImage(
              imageUrl: url,
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
        // Botão foto principal (canto inferior esquerdo)
        Positioned(
          bottom: 4,
          left: 4,
          child: GestureDetector(
            onTap: onToggleMain,
            child: Icon(
              isMain ? Icons.star_rounded : Icons.star_border_rounded,
              size: 22,
              color: isMain ? AppColors.secondary : Colors.white,
              shadows: const [
                Shadow(color: Colors.black54, blurRadius: 6),
              ],
            ),
          ),
        ),
        // Badge "Principal" quando selecionada
        if (isMain)
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: AppRadius.borderFull,
              ),
              child: Text(
                'Principal',
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onPrimary,
                  fontSize: 9,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
