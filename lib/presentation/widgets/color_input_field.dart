import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/color_codec.dart';

/// Saisie d'**une** couleur : on choisit d'abord le format (HEX / RGB /
/// iOS-macOS), puis on colle le code correspondant.
///
/// Pourquoi un sélecteur de format : les générateurs de palettes (huemint et
/// consorts) exportent selon le contexte. Obliger à convertir à la main serait
/// une source d'erreurs pour rien — on accepte le code tel qu'il est copié.
///
/// Changer de format **reconvertit** la valeur déjà saisie plutôt que de vider
/// le champ : on change d'unité, pas de couleur.
class ColorInputField extends StatefulWidget {
  /// Le rôle de cette couleur, en clair (« Fond de page »).
  final String label;

  /// À quoi elle sert dans l'app — c'est ce qui permet de choisir juste.
  final String usage;

  final Color? initial;
  final ValueChanged<Color?> onChanged;

  const ColorInputField({
    super.key,
    required this.label,
    required this.usage,
    required this.onChanged,
    this.initial,
  });

  @override
  State<ColorInputField> createState() => _ColorInputFieldState();
}

class _ColorInputFieldState extends State<ColorInputField> {
  final _ctrl = TextEditingController();
  ColorFormat _format = ColorFormat.hex;
  Color? _color;
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _color = widget.initial;
    if (_color != null) _ctrl.text = ColorCodec.format(_color!, _format);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onFormatChanged(ColorFormat f) {
    setState(() {
      _format = f;
      // On garde la couleur et on la réécrit dans la nouvelle unité.
      if (_color != null) {
        _ctrl.text = ColorCodec.format(_color!, f);
        _invalid = false;
      }
    });
  }

  void _onTextChanged(String v) {
    final parsed = ColorCodec.parse(v, _format);
    setState(() {
      _color = parsed;
      _invalid = v.trim().isNotEmpty && parsed == null;
    });
    widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // L'échantillon : le retour immédiat que le code est bien lu.
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _color ?? AppColors.surfaceContainerHigh,
                borderRadius: AppRadius.borderSm,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: _color == null
                  ? Icon(
                      Icons.question_mark,
                      size: 14,
                      color: AppColors.onSurfaceVariant,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label, style: AppTypography.labelMd),
                  Text(
                    widget.usage,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final formatField = DropdownButtonFormField<ColorFormat>(
              initialValue: _format,
              decoration: const InputDecoration(
                labelText: 'Format',
                isDense: true,
              ),
              items: ColorFormat.values
                  .map((f) => DropdownMenuItem(value: f, child: Text(f.label)))
                  .toList(),
              onChanged: (f) => _onFormatChanged(f ?? _format),
            );
            final codeField = TextField(
              controller: _ctrl,
              onChanged: _onTextChanged,
              style: AppTypography.dataMd,
              decoration: InputDecoration(
                labelText: 'Code couleur',
                hintText: _format.hint,
                helperText: _invalid
                    ? 'Code illisible dans ce format. ${_format.help}'
                    : _format.help,
                helperMaxLines: 2,
                errorText: _invalid ? '' : null,
                errorStyle: const TextStyle(height: 0, fontSize: 0),
                isDense: true,
              ),
            );
            // Sous 380px, le format passe au-dessus du code.
            if (constraints.maxWidth < 380) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  formatField,
                  const SizedBox(height: AppSpacing.sm),
                  codeField,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 132, child: formatField),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: codeField),
              ],
            );
          },
        ),
      ],
    );
  }
}
