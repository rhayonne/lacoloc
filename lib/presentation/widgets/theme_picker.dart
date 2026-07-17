import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/datasources/themes.dart';
import 'package:lacoloc_front/data/models/theme_ref.dart';
import 'package:lacoloc_front/presentation/widgets/theme_preview.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_palette.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/theme/theme_controller.dart';

/// Section « Apparence » — choix du thème, à poser dans n'importe quelle page
/// de profil (propriétaire, locataire, admin).
///
/// Le choix s'applique **immédiatement** (tout l'écran change sous les yeux)
/// puis est enregistré dans le profil. Si l'enregistrement échoue, on le dit et
/// on revient au thème précédent : garder à l'écran un thème qui sera perdu au
/// prochain démarrage induirait en erreur.
///
/// Les thèmes viennent de la base (`Themes_Reference`, gérés par le super
/// admin) : seuls les thèmes **actifs** sont proposés ici.
class ThemePickerSection extends StatefulWidget {
  const ThemePickerSection({super.key});

  @override
  State<ThemePickerSection> createState() => _ThemePickerSectionState();
}

class _ThemePickerSectionState extends State<ThemePickerSection> {
  late Future<List<ThemeRef>> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = ThemesDatasource.listActive();
  }

  Future<void> _choose(ThemeRef theme) async {
    if (_saving || theme.code == ThemeController.instance.code) return;
    final previous = ThemeController.instance.value;
    final previousCode = ThemeController.instance.code;
    setState(() => _saving = true);
    try {
      // Applique tout de suite (retour visuel immédiat) + enregistre.
      await AuthService.saveThemePreference(theme);
    } catch (e) {
      // Revient à l'état d'avant : mieux vaut le thème qu'on avait qu'un thème
      // qui disparaîtra au prochain démarrage.
      final back = ThemeController.instance.available
          .where((t) => t.code == previousCode)
          .firstOrNull;
      if (back != null) {
        ThemeController.instance.set(back);
      } else {
        ThemeController.instance.value = previous;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Le thème n\'a pas pu être enregistré : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'APPARENCE',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Le thème vous suit sur tous vos appareils.',
          style: AppTypography.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FutureBuilder<List<ThemeRef>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            final themes = snap.data ?? const <ThemeRef>[];
            if (themes.isEmpty) {
              return Text(
                'Aucun thème disponible pour le moment.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              );
            }
            return ValueListenableBuilder<AppPalette>(
              valueListenable: ThemeController.instance,
              builder: (context, _, _) {
                final currentCode = ThemeController.instance.code;
                return LayoutBuilder(
                  builder: (context, constraints) {
                    // 2 colonnes dès qu'il y a la place pour deux cartes lisibles.
                    final twoUp = constraints.maxWidth >= 460;
                    final cardWidth = twoUp
                        ? (constraints.maxWidth - AppSpacing.sm) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final t in themes)
                          SizedBox(
                            width: cardWidth,
                            child: _ThemeOption(
                              theme: t,
                              selected: t.code == currentCode,
                              enabled: !_saving,
                              onTap: () => _choose(t),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final ThemeRef theme;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.theme,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderLg,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: AppRadius.borderLg,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderLg,
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.outlineVariant,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ThemeSwatch(palette: theme.palette),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        theme.label,
                        style: AppTypography.titleLs,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppColors.primary,
                      ),
                  ],
                ),
                if (theme.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    theme.description!,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
