import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/presentation/messagerie/messagerie_model.dart';
import 'package:habitafrance/presentation/widgets/user_profile_card.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Couleur sémantique d'un état de demande, selon le point de vue.
Color statutColor(MessagerieRoleConfig config, DemandeContactModel d) {
  if (!config.isProprietaire) {
    return d.statut == StatutDemande.repondu
        ? AppColors.success
        : AppColors.onSurfaceVariant;
  }
  return switch (d.statut) {
    StatutDemande.nouveau => AppColors.primary,
    StatutDemande.nonRepondu => AppColors.secondary,
    StatutDemande.repondu => AppColors.success,
    StatutDemande.ignore => AppColors.onSurfaceVariant,
  };
}

/// **Bouton « Discuter »** — l'accès au fil, isolé dans sa propre colonne à
/// droite de la ligne (et non collé sous le badge d'état) pour qu'il soit
/// lisible et facile à viser. Sous ~520 px de large, il devient un bouton rond
/// à icône seule : la cible tactile reste ≥ 44 px, le libellé passe en tooltip.
class DiscussionActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool compact;
  final int unread;

  const DiscussionActionButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.unread = 0,
  });

  @override
  Widget build(BuildContext context) {
    final icone = Badge(
      isLabelVisible: unread > 0,
      label: Text('$unread'),
      child: const Icon(Icons.chat_bubble_outline),
    );

    if (compact) {
      return Tooltip(
        message: 'Ouvrir la discussion',
        child: SizedBox(
          width: 48,
          height: 48,
          child: IconButton.filled(
            onPressed: onPressed,
            icon: icone,
            iconSize: 20,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
          ),
        ),
      );
    }

    return Tooltip(
      message: 'Ouvrir la discussion',
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: icone,
        label: const Text('Discuter'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
      ),
    );
  }
}

/// Une ligne de la liste des discussions — **la même pour les deux profils** :
/// seul l'interlocuteur affiché et le libellé d'état changent (via
/// [MessagerieRoleConfig]).
///
/// Trois zones : identité (avatar + pastille de non-lus), contenu (nom, bien,
/// extrait du dernier échange), puis **une colonne dédiée au bouton
/// « Discuter »**. Cliquer la ligne ouvre la *fiche de profil* ; cliquer le
/// bouton ouvre le *fil*.
class MessagerieRow extends StatelessWidget {
  final DemandeContactModel demande;

  /// Fiche de l'interlocuteur, filtrée par le serveur (peut manquer le temps du
  /// chargement → on affiche le bien, jamais un faux nom).
  final ProfileCardData? profil;
  final MessagerieRoleConfig config;
  final bool selected;
  final int unread;
  final String snippet;
  final VoidCallback onTap;
  final VoidCallback onDiscuter;

  const MessagerieRow({
    super.key,
    required this.demande,
    required this.profil,
    required this.config,
    required this.selected,
    required this.unread,
    required this.snippet,
    required this.onTap,
    required this.onDiscuter,
  });

  @override
  Widget build(BuildContext context) {
    final d = demande;
    final date = DateFormat('dd/MM/yyyy').format(d.createdAt);
    final couleur = statutColor(config, d);

    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 520;
        return Material(
          color: selected
              ? AppColors.primaryFixed.withValues(alpha: 0.35)
              : AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.borderLg,
          child: InkWell(
            borderRadius: AppRadius.borderLg,
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderLg,
                border: Border.all(
                  color:
                      selected ? AppColors.primary : AppColors.outlineVariant,
                ),
              ),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ProfileAvatar(nom: profil?.fullName, size: 44),
                      if (unread > 0)
                        Positioned(
                            right: -2, top: -2, child: UnreadDot(count: unread)),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(child: _contenu(profil?.fullName, date, couleur)),
                  const SizedBox(width: AppSpacing.sm),
                  // ── Colonne dédiée : rien d'autre que l'accès au fil ──
                  DiscussionActionButton(
                    onPressed: onDiscuter,
                    compact: compact,
                    unread: unread,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _contenu(String? nom, String date, Color couleur) {
    final bien = demande.bienLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          nom ?? '—',
          style: AppTypography.titleLs,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (bien.isNotEmpty)
          Text(
            bien,
            style: AppTypography.labelSm.copyWith(color: AppColors.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        if (snippet.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            '« $snippet »',
            style: AppTypography.bodyMd
                .copyWith(color: AppColors.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 6),
        // État + date sur une ligne qui s'enroule si la place manque.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ProfilePill(label: config.statutLabel(demande), color: couleur),
            Text(date,
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}
