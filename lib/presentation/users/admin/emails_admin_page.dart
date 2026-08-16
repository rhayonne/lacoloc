import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:habitafrance/data/datasources/platform_settings.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/utils/email_field.dart';

/// **Configuration → Emails administration** (super admin).
///
/// Deux adresses, deux usages distincts :
/// - **Nouveaux comptes** : reçoit les demandes de compte propriétaire. C'est
///   la porte du modèle payant — un propriétaire reste inactif tant qu'un
///   administrateur ne l'a pas activé.
/// - **Support** : adresse donnée aux utilisateurs (notamment dans l'e-mail
///   d'activation) pour joindre un humain.
///
/// L'écriture est réservée au super admin **par la RLS**, pas seulement par
/// cet écran : un admin système qui appellerait l'API directement obtiendrait
/// 0 ligne modifiée.
class EmailsAdminPage extends StatefulWidget {
  const EmailsAdminPage({super.key});

  @override
  State<EmailsAdminPage> createState() => _EmailsAdminPageState();
}

class _EmailsAdminPageState extends State<EmailsAdminPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  late Future<PlatformSettings> _future;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = PlatformSettingsDatasource.get();
  }

  Future<void> _save() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    setState(() => _saving = true);
    try {
      await PlatformSettingsDatasource.save(
        PlatformSettings(
          emailNouveauxComptes: form.value['email_nouveaux_comptes'] as String?,
          emailSupport: form.value['email_support'] as String?,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Adresses enregistrées')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: 'Emails administration',
          subtitle: 'Où arrivent les demandes de la plateforme',
          trailing: AppButton.save(
            label: 'Enregistrer',
            onPressed: _saving ? null : _save,
            isBusy: _saving,
          ),
        ),
        Expanded(
          child: FutureBuilder<PlatformSettings>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: Text('Erreur : ${snap.error}'));
              }
              final s = snap.data ?? PlatformSettings.vide;

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: FormBuilder(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _carte(
                            icone: Icons.how_to_reg_outlined,
                            titre: 'Nouveaux comptes',
                            explication:
                                'Adresse qui reçoit chaque demande de compte '
                                'propriétaire, avec les informations saisies. '
                                'Un propriétaire reste inactif tant qu\'un '
                                'administrateur ne l\'a pas activé.',
                            champ: EmailField(
                              name: 'email_nouveaux_comptes',
                              labelText: 'E-mail — nouveaux comptes',
                              initialValue: s.emailNouveauxComptes,
                              hintText: 'comptes@habitafrance.fr',
                            ),
                            avertissement: s.emailNouveauxComptes == null
                                ? 'Aucune adresse : les demandes n\'arrivent '
                                      'que dans les notifications du tableau de '
                                      'bord.'
                                : null,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _carte(
                            icone: Icons.support_agent_outlined,
                            titre: 'Support',
                            explication:
                                'Adresse communiquée aux utilisateurs, '
                                'notamment dans l\'e-mail d\'activation, pour '
                                'joindre un administrateur.',
                            champ: EmailField(
                              name: 'email_support',
                              labelText: 'E-mail — support',
                              initialValue: s.emailSupport,
                              hintText: 'support@habitafrance.fr',
                            ),
                            avertissement: s.emailSupport == null
                                ? 'Aucune adresse : l\'e-mail d\'activation ne '
                                      'proposera pas de contact.'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _carte({
    required IconData icone,
    required String titre,
    required String explication,
    required Widget champ,
    String? avertissement,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icone, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(titre, style: AppTypography.titleLg),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            explication,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          champ,
          if (avertissement != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    avertissement,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
