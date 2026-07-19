import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/themes.dart';
import 'package:lacoloc_front/data/models/theme_ref.dart';
import 'package:lacoloc_front/presentation/widgets/color_input_field.dart';
import 'package:lacoloc_front/presentation/widgets/theme_preview.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/palette_builder.dart';

/// Crée ou modifie un thème à partir de **3 couleurs**.
/// Renvoie `true` si quelque chose a été enregistré.
Future<bool?> showThemeDialog(BuildContext context, {ThemeRef? existing}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => Dialog(child: _ThemeForm(existing: existing)),
  );
}

class _ThemeForm extends StatefulWidget {
  final ThemeRef? existing;
  const _ThemeForm({this.existing});

  @override
  State<_ThemeForm> createState() => _ThemeFormState();
}

class _ThemeFormState extends State<_ThemeForm> {
  final _labelCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  Color? _surface;
  Color? _ink;
  Color? _action;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _labelCtrl.text = e.label;
      _descCtrl.text = e.description ?? '';
      _surface = e.colorSurface;
      _ink = e.colorOnSurface;
      _action = e.colorPrimary;
    }
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  /// Les 3 couleurs sont-elles là ? (Sans elles, rien à prévisualiser.)
  bool get _complete => _surface != null && _ink != null && _action != null;

  PaletteDerivation? get _derivation => _complete
      ? PaletteBuilder.derive(surface: _surface!, ink: _ink!, action: _action!)
      : null;

  /// `Mon Thème` → `mon-theme`. Le code est l'identifiant stable stocké en
  /// base ; il ne change plus après la création.
  String _slug(String label) {
    const from = 'àáâäãåçèéêëìíîïñòóôöõùúûüýÿ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyy';
    var s = label.toLowerCase().trim();
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return s.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _save() async {
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      _snack('Donnez un nom au thème.');
      return;
    }
    if (!_complete) {
      _snack('Renseignez les trois couleurs.');
      return;
    }
    final code = _isEditing ? widget.existing!.code : _slug(label);
    if (code.isEmpty) {
      _snack('Ce nom ne permet pas de créer un identifiant. Utilisez des lettres.');
      return;
    }
    setState(() => _saving = true);
    try {
      final model = ThemeRef(
        id: widget.existing?.id ?? 0,
        code: code,
        label: label,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        colorSurface: _surface,
        colorOnSurface: _ink,
        colorPrimary: _action,
        isActive: widget.existing?.isActive ?? true,
        ordre: widget.existing?.ordre ?? 100,
      );
      if (_isEditing) {
        await ThemesDatasource.update(widget.existing!.id, model);
      } else {
        await ThemesDatasource.create(model);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      final msg = e.toString().contains('duplicate') ||
              e.toString().contains('unique')
          ? 'Un thème porte déjà ce nom. Choisissez-en un autre.'
          : 'Erreur : $e';
      _snack(msg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final derivation = _derivation;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 720),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── En-tête ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              children: [
                Icon(Icons.palette_outlined, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _isEditing ? 'Modifier le thème' : 'Nouveau thème',
                    style: AppTypography.titleLg,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Annuler',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Générez une palette sur huemint.com, puis collez les trois '
                    'couleurs ci-dessous. Le reste (surfaces, bordures, textes '
                    'secondaires) est calculé à partir d\'elles.',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  TextField(
                    controller: _labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom du thème',
                      hintText: 'Ex. : Lagune',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Une phrase, affichée sous le nom.',
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),

                  // ── Les 3 couleurs ─────────────────────────────────────
                  ColorInputField(
                    label: 'Fond de page',
                    usage: 'Le papier : le fond de toutes les pages.',
                    initial: _surface,
                    onChanged: (c) => setState(() => _surface = c),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ColorInputField(
                    label: 'Texte',
                    usage: 'L\'encre : titres et texte courant.',
                    initial: _ink,
                    onChanged: (c) => setState(() => _ink = c),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ColorInputField(
                    label: 'Action',
                    usage: 'Boutons principaux, menu actif, liens.',
                    initial: _action,
                    onChanged: (c) => setState(() => _action = c),
                  ),

                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),

                  // ── Aperçu ─────────────────────────────────────────────
                  Text('Aperçu', style: AppTypography.titleLs),
                  const SizedBox(height: AppSpacing.sm),
                  if (derivation == null)
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: AppRadius.borderMd,
                        border: Border.all(color: AppColors.outlineVariant),
                      ),
                      child: Text(
                        'Renseignez les trois couleurs pour voir l\'aperçu.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    )
                  else ...[
                    if (derivation.warnings.isNotEmpty) ...[
                      _WarningsBox(warnings: derivation.warnings),
                      const SizedBox(height: AppSpacing.md),
                    ],
                    ThemeSitePreview(palette: derivation.palette),
                  ],
                ],
              ),
            ),
          ),
          // ── Actions ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  style: AppTheme.cancelButtonStyle,
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: AppSpacing.sm),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  style: AppTheme.saveButtonStyle,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(_isEditing ? 'Enregistrer' : 'Créer le thème'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ce que le système a corrigé tout seul pour garder l'interface lisible.
/// On le montre au lieu de le faire en douce : la personne doit savoir que la
/// couleur affichée n'est pas exactement celle qu'elle a collée.
class _WarningsBox extends StatelessWidget {
  final List<String> warnings;
  const _WarningsBox({required this.warnings});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryFixed,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_fix_high, size: 18, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajusté automatiquement',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.onSecondaryFixed,
                  ),
                ),
                const SizedBox(height: 2),
                for (final w in warnings)
                  Text(
                    '• $w',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSecondaryFixed,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
