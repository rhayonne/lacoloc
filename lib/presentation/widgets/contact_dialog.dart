import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/demandes_contact.dart';
import 'package:habitafrance/data/models/users_client.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Pop-up **« Entrer en contact »** (locataire → propriétaire), partagé par la
/// fiche chambre **et** la fiche immeuble. En-tête avec le nom du propriétaire,
/// **avertissement** des données partagées (toujours affiché), zone de saisie
/// du message, boutons **Annuler / Envoyer** (standards du thème). À l'envoi :
/// crée la demande + envoie le premier message (plus d'acceptation).
///
/// [chambreId]/[chambreName] optionnels : contact au niveau de l'immeuble
/// (annonce d'immeuble) quand ils sont nuls. [onSent] est appelé après succès.
Future<void> showContactDialog(
  BuildContext context, {
  required UsersClient profile,
  required int immeubleId,
  required String immeubleName,
  int? chambreId,
  String? chambreName,
  VoidCallback? onSent,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _ContactDialog(
      profile: profile,
      immeubleId: immeubleId,
      immeubleName: immeubleName,
      chambreName: chambreName,
      onConfirm: (message) async {
        Navigator.of(ctx).pop();
        try {
          await DemandesContactDatasource.createWithMessage(
            locataireId: profile.id,
            immeubleId: immeubleId,
            chambreId: chambreId,
            message: message,
          );
          onSent?.call();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Votre message a été envoyé au propriétaire.'),
              ),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Erreur : $e')));
          }
        }
      },
    ),
  );
}

class _ContactDialog extends StatefulWidget {
  final UsersClient profile;
  final int immeubleId;
  final String immeubleName;
  final String? chambreName;
  final Future<void> Function(String message) onConfirm;

  const _ContactDialog({
    required this.profile,
    required this.immeubleId,
    required this.immeubleName,
    required this.chambreName,
    required this.onConfirm,
  });

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  bool _loading = false;
  final _msgCtrl = TextEditingController();
  String? _proprioNom;

  @override
  void initState() {
    super.initState();
    _loadProprio();
  }

  Future<void> _loadProprio() async {
    final nom =
        await DemandesContactDatasource.proprietaireNom(widget.immeubleId);
    if (mounted) setState(() => _proprioNom = nom);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderLg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          // Défilable : sur petit écran le contenu + le clavier dépasseraient
          // sinon (multiplateforme).
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.contact_mail_outlined,
                        color: AppColors.primary, size: 22),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Entrer en contact',
                              style: AppTypography.titleLg),
                          Text(
                            _proprioNom != null
                                ? 'Votre message sera envoyé à $_proprioNom'
                                : 'Propriétaire de l\'annonce',
                            style: AppTypography.labelSm
                                .copyWith(color: AppColors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Fermer',
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
                Text(
                  'En envoyant ce message, vous acceptez de transmettre les '
                  'informations suivantes — nom complet, âge, numéro de '
                  'téléphone et adresse e-mail — au propriétaire du bien afin '
                  'qu\'il puisse vous répondre.',
                  style: AppTypography.bodyMd,
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(color: AppColors.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow(
                          icon: Icons.person_outline,
                          label: 'Nom complet',
                          value: p.fullName ?? '—'),
                      _InfoRow(
                          icon: Icons.cake_outlined,
                          label: 'Âge',
                          value: p.calculatedAge != null
                              ? '${p.calculatedAge} ans'
                              : '—'),
                      _InfoRow(
                          icon: Icons.phone_outlined,
                          label: 'Téléphone',
                          value: p.phone ?? '—'),
                      _InfoRow(
                          icon: Icons.email_outlined,
                          label: 'E-mail',
                          value: p.email),
                      const Divider(height: AppSpacing.lg),
                      if (widget.chambreName != null)
                        _InfoRow(
                            icon: Icons.bed_outlined,
                            label: 'Chambre',
                            value: widget.chambreName!),
                      _InfoRow(
                          icon: Icons.apartment_outlined,
                          label: 'Immeuble',
                          value: widget.immeubleName),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Votre message',
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xs),
                TextField(
                  controller: _msgCtrl,
                  enabled: !_loading,
                  minLines: 3,
                  maxLines: 6,
                  textInputAction: TextInputAction.newline,
                  // Un message vide créerait une demande fantôme (sans aucun
                  // message) : on garde le bouton actif seulement s'il y a du
                  // texte → rebuild à chaque frappe.
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText:
                        'Bonjour, je suis intéressé(e) par cette annonce…',
                    border:
                        OutlineInputBorder(borderRadius: AppRadius.borderMd),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AppButton.cancel(
                      size: AppButtonSize.compact,
                      label: 'Annuler',
                      onPressed:
                          _loading ? null : () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    AppButton.primary(
                      size: AppButtonSize.compact,
                      icon: Icons.send_outlined,
                      label: 'Envoyer',
                      isBusy: _loading,
                      onPressed: (_loading || _msgCtrl.text.trim().isEmpty)
                          ? null
                          : () async {
                              setState(() => _loading = true);
                              await widget.onConfirm(_msgCtrl.text);
                            },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Text('$label : ',
              style: AppTypography.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
          Expanded(child: Text(value, style: AppTypography.bodyMd)),
        ],
      ),
    );
  }
}
