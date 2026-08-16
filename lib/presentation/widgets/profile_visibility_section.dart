import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/data/models/profile_visibility.dart';
import 'package:habitafrance/data/models/users_client.dart';
import 'package:habitafrance/presentation/widgets/user_profile_card.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Section **« Ma fiche de profil »** de l'écran Mon Profil : l'utilisateur y
/// choisit, champ par champ, ce que l'autre partie voit de lui — un locataire
/// pour un propriétaire, et inversement.
///
/// Chaque champ a un **interrupteur** (et non une case à cocher) : l'état
/// « montré / masqué » se lit d'un coup d'œil et s'inverse d'un geste. Le
/// changement est enregistré **immédiatement** (pas de bouton « Sauvegarder » à
/// ne pas oublier) ; en cas d'échec l'interrupteur revient à sa position réelle
/// et l'erreur est affichée — un réglage de confidentialité ne doit jamais
/// paraître appliqué alors qu'il ne l'est pas.
///
/// L'aperçu en bas utilise le **même** [UserProfileCard] que la messagerie : ce
/// que l'utilisateur voit ici est littéralement ce que l'autre verra.
class ProfileVisibilitySection extends StatefulWidget {
  final UsersClient? profile;

  /// Qui verra cette fiche — « aux locataires », « aux propriétaires »…
  final String audience;

  const ProfileVisibilitySection({
    super.key,
    required this.profile,
    required this.audience,
  });

  @override
  State<ProfileVisibilitySection> createState() =>
      _ProfileVisibilitySectionState();
}

class _ProfileVisibilitySectionState extends State<ProfileVisibilitySection> {
  late ProfileVisibility _visibility =
      widget.profile?.profileVisibility ?? ProfileVisibility.defaults;

  /// Champ en cours d'enregistrement (interrupteur figé le temps de l'écriture).
  ProfileVisibilityField? _saving;

  Future<void> _toggle(ProfileVisibilityField field, bool value) async {
    final previous = _visibility;
    setState(() {
      _visibility = _visibility.withField(field, value);
      _saving = field;
    });
    try {
      await AuthService.updateProfileVisibility(_visibility);
    } catch (e) {
      if (!mounted) return;
      setState(() => _visibility = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'enregistrer ce réglage : $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ma fiche de profil', style: AppTypography.titleLg),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Choisissez ce qui apparaît dans la fiche montrée ${widget.audience}. '
          'Activez l\'interrupteur d\'un champ pour l\'afficher, désactivez-le '
          'pour le retirer de votre fiche.',
          style:
              AppTypography.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Dire ce que le réglage fait — et ce qu'il ne fait pas. Promettre la
        // confidentialité serait faux : le masquage retire de l'affichage.
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow,
            borderRadius: AppRadius.borderMd,
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 18, color: AppColors.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Ces réglages contrôlent l\'affichage de votre fiche dans '
                  'l\'application. Ils ne retirent pas les informations que '
                  'vous auriez déjà écrites dans un message.',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: AppRadius.borderMd,
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              // Le nom n'est pas négociable : sans lui, l'autre partie ne sait
              // pas à qui elle écrit. On l'affiche donc, verrouillé et expliqué.
              _row(
                icon: Icons.person_outline,
                label: 'Nom complet',
                hint: 'Toujours affiché : votre interlocuteur doit savoir '
                    'à qui il s\'adresse.',
                value: true,
                onChanged: null,
              ),
              for (final field in ProfileVisibilityField.values) ...[
                Divider(height: 1, color: AppColors.outlineVariant),
                _row(
                  icon: _iconOf(field),
                  label: field.label,
                  hint: field.hint,
                  value: _visibility.isVisible(field),
                  busy: _saving == field,
                  onChanged: _saving != null
                      ? null
                      : (v) => _toggle(field, v),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.lg),
        Text('Aperçu',
            style: AppTypography.labelMd
                .copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Voici exactement la fiche que verra votre interlocuteur.',
          style:
              AppTypography.labelSm.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: AppRadius.borderMd,
          child: Container(
            height: 340,
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderMd,
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: UserProfileCard(
              data: ProfileCardData.fromUsersClient(
                widget.profile,
                visibility: _visibility,
              ),
            ),
          ),
        ),
      ],
    );
  }

  static IconData _iconOf(ProfileVisibilityField f) => switch (f) {
        ProfileVisibilityField.age => Icons.cake_outlined,
        ProfileVisibilityField.phone => Icons.phone_outlined,
        ProfileVisibilityField.email => Icons.mail_outline,
      };

  Widget _row({
    required IconData icon,
    required String label,
    required String hint,
    required bool value,
    ValueChanged<bool>? onChanged,
    bool busy = false,
  }) {
    final locked = onChanged == null && !busy;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon,
              size: 18,
              color:
                  value ? AppColors.primary : AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.bodyMd),
                const SizedBox(height: 1),
                Text(hint,
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Tooltip(
              message: locked
                  ? 'Ce champ est toujours visible'
                  : (value ? 'Affiché — cliquez pour masquer'
                          : 'Masqué — cliquez pour afficher'),
              child: Switch(value: value, onChanged: onChanged),
            ),
        ],
      ),
    );
  }
}
