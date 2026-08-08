import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/themes.dart';
import 'package:habitafrance/data/models/theme_ref.dart';
import 'package:habitafrance/presentation/users/admin/theme_dialog.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/presentation/widgets/theme_preview.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_palette.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/theme/theme_controller.dart';

/// Super admin → Configuration → **Thèmes**.
///
/// Chaque thème est un accordéon : replié, on voit ses couleurs ; déplié, une
/// maquette du site avec ces couleurs et la légende « quelle couleur sert à
/// quoi ». Les réglages sont là aussi :
/// - **Proposé aux utilisateurs** — le thème apparaît (ou non) dans « Mon profil ».
/// - **Thème principal** — celui que voient les visiteurs et les nouveaux comptes.
///   Il n'écrase jamais un choix déjà fait par quelqu'un.
class ThemesAdminPage extends StatefulWidget {
  const ThemesAdminPage({super.key});

  @override
  State<ThemesAdminPage> createState() => _ThemesAdminPageState();
}

class _ThemesAdminPageState extends State<ThemesAdminPage> {
  late Future<List<ThemeRef>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final f = ThemesDatasource.listAll(refresh: true);
    setState(() { _future = f; });
  }

  /// Après toute écriture : la liste ET le thème courant peuvent avoir changé
  /// (ex. on vient de désactiver le thème qu'on portait).
  Future<void> _afterWrite() async {
    _reload();
    await ThemeController.instance.loadDefault(refresh: true);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _afterWrite();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _nouveau() async {
    final ok = await showThemeDialog(context);
    if (ok == true) await _afterWrite();
  }

  Future<void> _modifier(ThemeRef t) async {
    final ok = await showThemeDialog(context, existing: t);
    if (ok == true) await _afterWrite();
  }

  Future<void> _supprimer(ThemeRef t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce thème ?'),
        content: Text(
          'Le thème « ${t.label} » sera supprimé définitivement. Les comptes '
          'qui l\'avaient choisi repasseront au thème principal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: AppTheme.deleteButtonStyle,
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => ThemesDatasource.delete(t.id));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Thèmes',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _nouveau,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ajouter un thème'),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.outlined(
                icon: const Icon(Icons.refresh),
                onPressed: _busy ? null : _reload,
                tooltip: 'Actualiser',
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<ThemeRef>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              final themes = snap.data ?? const <ThemeRef>[];
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  _intro(),
                  const SizedBox(height: AppSpacing.md),
                  for (final t in themes) ...[
                    _ThemeAccordion(
                      theme: t,
                      busy: _busy,
                      onToggleActive: (v) =>
                          _run(() => ThemesDatasource.setActive(t.id, v)),
                      onMakeDefault: () =>
                          _run(() => ThemesDatasource.setDefault(t.id)),
                      onEdit: () => _modifier(t),
                      onDelete: () => _supprimer(t),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _intro() => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.surfaceContainerLowest,
      borderRadius: AppRadius.borderLg,
      border: Border.all(color: AppColors.outlineVariant),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 3,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: AppRadius.borderFull,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Un thème se compose de trois couleurs',
                style: AppTypography.labelMd,
              ),
              const SizedBox(height: 2),
              Text(
                'Le fond de page, le texte et la couleur d\'action. Générez-les '
                'sur huemint.com, collez-les ici : le reste de la palette est '
                'calculé, et le contraste corrigé si besoin. Ouvrez un thème '
                'pour voir à quoi ressemblerait le site.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────

class _ThemeAccordion extends StatelessWidget {
  final ThemeRef theme;
  final bool busy;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onMakeDefault;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ThemeAccordion({
    required this.theme,
    required this.busy,
    required this.onToggleActive,
    required this.onMakeDefault,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        // Replié : les couleurs du thème tiennent lieu d'icône — on reconnaît
        // un thème à ses couleurs, pas à un pictogramme.
        leading: _ColorDots(palette: p),
        title: Row(
          children: [
            Flexible(
              child: Text(
                theme.label,
                style: AppTypography.titleLs,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (theme.isDefault) ...[
              const SizedBox(width: AppSpacing.sm),
              _Badge(
                label: 'Principal',
                bg: AppColors.primaryFixed,
                fg: AppColors.onPrimaryFixedVariant,
              ),
            ],
            if (!theme.isActive) ...[
              const SizedBox(width: AppSpacing.xs),
              _Badge(
                label: 'Masqué',
                bg: AppColors.surfaceContainerHigh,
                fg: AppColors.onSurfaceVariant,
              ),
            ],
          ],
        ),
        subtitle: Text(
          theme.description ?? (theme.isBuiltin ? 'Thème intégré' : ''),
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        children: [
          ThemeSitePreview(palette: p),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          _settings(context),
        ],
      ),
    );
  }

  Widget _settings(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Proposé ou non aux utilisateurs.
        SwitchListTile(
          value: theme.isActive,
          onChanged: busy || theme.isDefault ? null : onToggleActive,
          contentPadding: EdgeInsets.zero,
          title: Text('Proposé aux utilisateurs', style: AppTypography.labelMd),
          subtitle: Text(
            theme.isDefault
                ? 'Le thème principal est toujours proposé.'
                : 'Apparaît dans « Mon profil → Apparence ».',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        // Thème principal.
        CheckboxListTile(
          value: theme.isDefault,
          onChanged: busy || theme.isDefault
              ? null
              : (_) => onMakeDefault(),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text('Thème principal', style: AppTypography.labelMd),
          subtitle: Text(
            'Vu par les visiteurs et les nouveaux comptes. Ceux qui ont déjà '
            'choisi un thème gardent le leur.',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            if (theme.isBuiltin)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Thème intégré : ses couleurs vivent dans le code.',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              OutlinedButton.icon(
                onPressed: busy ? null : onEdit,
                style: AppTheme.editButtonStyle,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Modifier'),
              ),
              FilledButton.icon(
                onPressed: busy || theme.isDefault ? null : onDelete,
                style: AppTheme.deleteButtonStyle,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: Text(
                  theme.isDefault
                      ? 'Principal : non supprimable'
                      : 'Supprimer',
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Les couleurs du thème, en pastilles — c'est ce qui identifie un thème d'un
/// coup d'œil dans la liste.
class _ColorDots extends StatelessWidget {
  final AppPalette palette;
  const _ColorDots({required this.palette});

  @override
  Widget build(BuildContext context) {
    // Les 3 couleurs sources d'un thème, dans l'ordre où on les saisit.
    final colors = <Color>[
      palette.surface,
      palette.onSurface,
      palette.primary,
    ];
    return SizedBox(
      width: 46,
      height: 26,
      child: Stack(
        children: [
          for (var i = 0; i < colors.length; i++)
            Positioned(
              left: i * 13.0,
              top: 3,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colors[i],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.surfaceContainerLowest,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: AppRadius.borderFull),
    child: Text(
      label,
      style: AppTypography.labelSm.copyWith(
        color: fg,
        fontWeight: FontWeight.w700,
        fontSize: 10,
      ),
    ),
  );
}
