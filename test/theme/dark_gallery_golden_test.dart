import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_palette.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/theme/theme_controller.dart';

/// **Planche de contrôle visuel** d'une palette.
///
/// Les tests de contraste disent qu'un couple texte/fond passe ; ils ne disent
/// pas à quoi la page ressemble. Cette planche rassemble les composants réels
/// (barre de titre, cartes, boutons de chaque variante, champs, pastilles,
/// liens, tableau) pour qu'on puisse *regarder* un thème avant de le livrer.
///
/// ```
/// flutter test test/theme/dark_gallery_golden_test.dart \
///   --dart-define=THEME_GALLERY=true --update-goldens
/// ```
/// puis ouvrir `test/theme/goldens/*.png`.
///
/// **Hors CI par défaut**, d'où l'interrupteur `THEME_GALLERY` : ce sont des
/// planches à *regarder*, pas des références à figer. Les comparer à chaque
/// exécution ferait échouer le build à la moindre retouche de palette sans rien
/// apprendre à personne — et le rendu du texte dépend ici de polices que
/// l'environnement de test ne télécharge pas.
/// Ce qui, lui, est vérifié automatiquement : `builtin_palettes_test.dart`
/// (contrastes) et `dark_theme_wiring_test.dart` (branchement du thème).
const _galerieActive = bool.fromEnvironment('THEME_GALLERY');
Widget _planche(String titre) => Builder(
  builder: (context) => Container(
    color: AppColors.surface,
    padding: const EdgeInsets.only(bottom: AppSpacing.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTopBar(
          title: titre,
          subtitle: 'Sous-titre de la barre',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppButton.save(label: 'Enregistrer', onPressed: () {}),
              const SizedBox(width: AppSpacing.sm),
              AppButton.cancel(label: 'Fermer', onPressed: () {}),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Titre de carte', style: AppTypography.titleLg),
                      const SizedBox(height: 4),
                      Text(
                        'Texte principal : le corps de la fiche, celui qu\'on '
                        'lit longtemps.',
                        style: AppTypography.bodyMd,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Texte secondaire : légende, libellé, mention.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {},
                            child: const Text('Un lien cliquable'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(
                            '1 250,00 €',
                            style: AppTypography.dataMd,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  AppButton.primary(label: 'Action', onPressed: () {}),
                  AppButton.save(label: 'Enregistrer', onPressed: () {}),
                  AppButton.delete(label: 'Supprimer', onPressed: () {}),
                  AppButton.edit(label: 'Modifier', onPressed: () {}),
                  AppButton.document(label: 'Document', onPressed: () {}),
                  AppButton.cancel(label: 'Annuler', onPressed: () {}),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // Pastilles / badges : fond teinté + son texte.
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  _pastille('Signé', AppColors.successFixed,
                      AppColors.onSuccessFixed),
                  _pastille('En attente', AppColors.secondaryFixed,
                      AppColors.onSecondaryFixed),
                  _pastille('À signer', AppColors.primaryFixed,
                      AppColors.onPrimaryFixed),
                  _pastille('En litige', AppColors.errorContainer,
                      AppColors.onErrorContainer),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: AppRadius.borderFull,
                    ),
                    child: Text('3',
                        style: AppTypography.labelSm
                            .copyWith(color: AppColors.onError)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'Libellé du champ',
                  hintText: 'Texte d\'aide',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // En-tête de tableau + une ligne (surfaces hautes).
              Container(
                color: AppColors.surfaceContainerHigh,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('LOCATAIRE',
                          style: AppTypography.labelSm
                              .copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                    Expanded(
                      child: Text('SITUATION',
                          style: AppTypography.labelSm
                              .copyWith(color: AppColors.onSurfaceVariant)),
                    ),
                  ],
                ),
              ),
              Container(
                color: AppColors.surfaceContainerLowest,
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Marie Dupont', style: AppTypography.bodyMd),
                    ),
                    Expanded(
                      child: Text('Finalisé',
                          style: AppTypography.bodyMd
                              .copyWith(color: AppColors.success)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  ),
);

Widget _pastille(String texte, Color fond, Color encre) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  decoration: BoxDecoration(color: fond, borderRadius: AppRadius.borderFull),
  child: Text(texte, style: AppTypography.labelSm.copyWith(color: encre)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final initiale = ThemeController.instance.value;
  tearDown(() => ThemeController.instance.value = initiale);

  for (final entree in <String, AppPalette>{
    'sombre': AppPalettes.sombre,
    'ardoise': AppPalettes.ardoise,
  }.entries) {
    testWidgets('planche — ${entree.key}', (tester) async {
      ThemeController.instance.value = entree.value;
      tester.view.physicalSize = const Size(1000, 1500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.current,
          home: Scaffold(
            body: SingleChildScrollView(
              child: _planche('Aperçu du thème ${entree.key}'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/theme_${entree.key}.png'),
      );
    }, skip: !_galerieActive);
  }
}
