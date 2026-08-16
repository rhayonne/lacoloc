import 'package:flutter/material.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/data/models/profile_visibility.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Lien secondaire du corps de la fiche (ex. « Voir l'annonce »).
class ProfileCardLink {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const ProfileCardLink({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// **Fiche de profil réutilisable** — la carte « qui est cette personne »,
/// identique partout (messagerie des deux profils, aperçu de son propre profil,
/// et tout écran futur qui doit présenter quelqu'un).
///
/// Elle n'affiche que ce que la personne a accepté de montrer : le filtrage est
/// fait en amont par [ProfileCardData] (préférences `profile_visibility`), donc
/// cet écran ne peut pas révéler un champ masqué par erreur.
///
/// Structure : en-tête (avatar + nom + sous-titre + badge, bouton **Fermer**) ·
/// corps défilable (champs visibles + liens) · pied optionnel ([actions]).
/// Responsive : le pied empile ses boutons en colonne sous ~360 px de large.
class UserProfileCard extends StatelessWidget {
  final ProfileCardData data;

  /// Badge d'état affiché sous le nom (ex. statut de la demande).
  final Widget? badge;

  /// Ferme la fiche (croix en haut à droite). Null = pas de croix.
  final VoidCallback? onClose;

  /// Retour (flèche à gauche) — utile quand la fiche occupe tout l'écran.
  final VoidCallback? onBack;

  /// Boutons du pied de carte (ex. E-mail / Discuter).
  final List<Widget> actions;

  /// Liens du corps (ex. « Voir l'annonce »).
  final List<ProfileCardLink> links;

  const UserProfileCard({
    super.key,
    required this.data,
    this.badge,
    this.onClose,
    this.onBack,
    this.actions = const [],
    this.links = const [],
  });

  @override
  Widget build(BuildContext context) {
    final fields = data.visibleFields;

    return Container(
      color: AppColors.surfaceContainerLowest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                if (fields.isEmpty)
                  _rienAPartager()
                else
                  for (final entry in fields.entries)
                    _field(_iconOf(entry.key), entry.key.label, entry.value),
                for (final link in links)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        icon: Icon(link.icon, size: 16),
                        label: Text(link.label),
                        onPressed: link.onTap,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (actions.isNotEmpty) _footer(),
        ],
      ),
    );
  }

  // ── En-tête ────────────────────────────────────────────────────────────────

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.withValues(alpha: 0.25),
        border: Border(bottom: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: Column(
        children: [
          // Ligne d'outils : retour à gauche, fermeture à droite. Toujours
          // présente (hauteur constante) pour que le bloc ne saute pas.
          SizedBox(
            height: 40,
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Retour',
                    onPressed: onBack,
                  ),
                const Spacer(),
                if (onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Fermer la fiche',
                    onPressed: onClose,
                  ),
              ],
            ),
          ),
          _Avatar(nom: data.fullName, size: 64),
          const SizedBox(height: AppSpacing.sm),
          Text(
            data.fullName ?? '—',
            style: AppTypography.titleLg,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if ((data.subtitle ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              data.subtitle!,
              style: AppTypography.labelSm.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (badge != null) ...[
            const SizedBox(height: AppSpacing.sm),
            badge!,
          ],
        ],
      ),
    );
  }

  // ── Corps ──────────────────────────────────────────────────────────────────

  static IconData _iconOf(ProfileVisibilityField f) => switch (f) {
        ProfileVisibilityField.age => Icons.cake_outlined,
        ProfileVisibilityField.phone => Icons.phone_outlined,
        ProfileVisibilityField.email => Icons.mail_outline,
      };

  Widget _rienAPartager() => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.visibility_off_outlined,
                size: 18, color: AppColors.onSurfaceVariant),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                'Aucune coordonnée partagée. '
                'Vous pouvez écrire à cette personne dans la messagerie.',
                style: AppTypography.bodyMd
                    .copyWith(color: AppColors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      );

  Widget _field(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(),
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                  const SizedBox(height: 1),
                  SelectableText(value, style: AppTypography.bodyMd),
                ],
              ),
            ),
          ],
        ),
      );

  // ── Pied ───────────────────────────────────────────────────────────────────

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.outlineVariant)),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          // Sous ~360 px, deux boutons côte à côte tronquent leur libellé :
          // on les empile.
          if (c.maxWidth < 360 && actions.length > 1) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < actions.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  actions[i],
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(child: actions[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Avatar à initiales, couleur déterministe tirée de la palette du thème.
class _Avatar extends StatelessWidget {
  final String? nom;
  final double size;
  const _Avatar({required this.nom, this.size = 42});

  static Color _color(String key) {
    final colors = [
      AppColors.primary,
      AppColors.secondary,
      AppColors.tertiary,
      AppColors.error,
    ];
    return colors[key.hashCode.abs() % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: _color(nom ?? '?'), shape: BoxShape.circle),
      child: Text(
        ProfileCardData.initials(nom),
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Avatar réutilisable hors de la fiche (lignes de liste, en-tête de fil).
class ProfileAvatar extends StatelessWidget {
  final String? nom;
  final double size;
  const ProfileAvatar({super.key, required this.nom, this.size = 42});

  @override
  Widget build(BuildContext context) => _Avatar(nom: nom, size: size);
}

/// Pastille ronde de messages non lus, superposable à un avatar.
class UnreadDot extends StatelessWidget {
  final int count;
  const UnreadDot({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      decoration: BoxDecoration(
        color: AppColors.error,
        shape: BoxShape.circle,
        border:
            Border.all(color: AppColors.surfaceContainerLowest, width: 2),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: AppTypography.labelSm
            .copyWith(color: AppColors.onError, fontSize: 10, height: 1),
      ),
    );
  }
}

/// Petit badge arrondi générique (statut, état…), style commun aux listes.
class ProfilePill extends StatelessWidget {
  final String label;
  final Color color;
  const ProfilePill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Text(label, style: AppTypography.labelSm.copyWith(color: color)),
        ],
      ),
    );
  }
}
