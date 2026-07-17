import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_palette.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:lacoloc_front/utils/color_codec.dart';

/// Aperçus d'une palette. **Tout ici se peint avec la palette passée en
/// paramètre**, jamais avec `AppColors` : on montre un thème qui n'est pas
/// (encore) le thème courant.
///
/// Deux niveaux :
/// - [ThemeSwatch] — le nuancier compact (sélecteur de « Mon profil »).
/// - [ThemeSitePreview] — la maquette du site + la légende « quelle couleur
///   sert à quoi » (écran d'administration).

/// Nuancier compact : le fond réel, le trait de marge, l'encre et les trois
/// couleurs porteuses. On voit ce qu'on choisit.
class ThemeSwatch extends StatelessWidget {
  final AppPalette palette;
  const ThemeSwatch({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: palette.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          // La barre de marquage : le langage de sélection de l'app.
          Container(width: 4, color: palette.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Deux « lignes de texte » factices : le contraste encre/papier.
                Container(
                  width: 54,
                  height: 5,
                  decoration: BoxDecoration(
                    color: palette.onSurface,
                    borderRadius: AppRadius.borderFull,
                  ),
                ),
                const SizedBox(height: 5),
                Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: palette.onSurfaceVariant,
                    borderRadius: AppRadius.borderFull,
                  ),
                ),
              ],
            ),
          ),
          for (final c in [
            palette.primary,
            palette.secondary,
            palette.tertiary,
          ]) ...[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(color: palette.surfaceContainerLowest),
              ),
            ),
            const SizedBox(width: 5),
          ],
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
    );
  }
}

/// Maquette du site avec la palette, suivie de la légende des rôles.
///
/// Le but est de répondre à une question précise : « cette couleur, elle sort
/// où ? ». On montre donc les vrais endroits — le menu, la barre de titre, une
/// carte, les boutons Enregistrer/Supprimer — plutôt qu'une grille de pastilles
/// abstraites.
class ThemeSitePreview extends StatelessWidget {
  final AppPalette palette;
  const ThemeSitePreview({super.key, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _mockup(),
        const SizedBox(height: AppSpacing.md),
        _legend(),
      ],
    );
  }

  // ── La maquette ───────────────────────────────────────────────────────────
  Widget _mockup() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Sous ~420px, le menu latéral disparaît (comme sur téléphone).
        final showSidebar = constraints.maxWidth >= 420;
        return Container(
          height: 208,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: palette.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showSidebar) _sidebar(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [_topBar(), Expanded(child: _content())],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sidebar() => Container(
    width: 104,
    color: palette.surfaceContainerLowest,
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius: AppRadius.borderSm,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'Super Loc',
                style: AppTypography.labelSm.copyWith(
                  color: palette.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
        _navItem('Accueil', active: true),
        _navItem('Chambres'),
        _navItem('Finances'),
      ],
    ),
  );

  Widget _navItem(String label, {bool active = false}) => Container(
    margin: const EdgeInsets.fromLTRB(6, 1, 6, 1),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
    decoration: BoxDecoration(
      color: active
          ? palette.primaryFixed.withValues(alpha: 0.45)
          : Colors.transparent,
      borderRadius: AppRadius.borderSm,
    ),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? palette.primary : palette.onSurfaceVariant,
            borderRadius: AppRadius.borderFull,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontSize: 9,
            color: active ? palette.primary : palette.onSurfaceVariant,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );

  Widget _topBar() => Container(
    height: 34,
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
    decoration: BoxDecoration(
      color: palette.surfaceContainerLowest,
      border: Border(bottom: BorderSide(color: palette.outlineVariant)),
    ),
    child: Row(
      children: [
        Text(
          'Mes Chambres',
          style: AppTypography.labelSm.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: palette.onSurface,
          ),
        ),
        const Spacer(),
        _pill('Ajouter', bg: palette.primary, fg: palette.onPrimary),
      ],
    ),
  );

  Widget _content() => Padding(
    padding: const EdgeInsets.all(AppSpacing.sm),
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surfaceContainerLowest,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: palette.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Chambre 1',
            style: AppTypography.labelSm.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: palette.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'APT test coloc · 15 Rue de Falaise',
            style: AppTypography.labelSm.copyWith(
              fontSize: 9,
              color: palette.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              _pill(
                '10 m²',
                bg: palette.surfaceContainerHigh,
                fg: palette.onSurfaceVariant,
              ),
              _pill(
                'Bail signé',
                bg: palette.tertiaryFixed,
                fg: palette.onTertiaryFixed,
              ),
              _pill(
                'À venir',
                bg: palette.secondaryFixed,
                fg: palette.onSecondaryFixed,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _pill(
                'Enregistrer',
                bg: palette.tertiaryFixed,
                fg: palette.onTertiaryFixed,
              ),
              const SizedBox(width: 4),
              _pill('Supprimer', bg: palette.error, fg: palette.onError),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _pill(String label, {required Color bg, required Color fg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.borderFull,
        ),
        child: Text(
          label,
          style: AppTypography.labelSm.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      );

  // ── La légende : quelle couleur sert à quoi ───────────────────────────────
  Widget _legend() {
    final rows = <(Color, String, String)>[
      (palette.surface, 'Fond de page', 'Le fond de toutes les pages'),
      (palette.onSurface, 'Texte', 'Titres et texte courant'),
      (
        palette.primary,
        'Action',
        'Boutons principaux, menu actif, liens',
      ),
      (
        palette.secondary,
        'Information',
        'Un état, une info — dérivée de l\'action',
      ),
      (palette.tertiary, 'Succès', 'Signé, payé, validé'),
      (palette.error, 'Erreur', 'Supprimer, litige, alerte'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (color, role, usage) in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.borderSm,
                    border: Border.all(color: palette.outlineVariant),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 92,
                  child: Text(
                    role,
                    style: AppTypography.labelSm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    usage,
                    style: AppTypography.labelSm.copyWith(
                      color: palette.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SelectableText(
                  ColorCodec.toHex(color),
                  style: AppTypography.dataSm,
                ),
              ],
            ),
          ),
      ],
    );
  }
}
