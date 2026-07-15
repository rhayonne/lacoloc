import 'package:flutter/material.dart';
import 'package:lacoloc_front/presentation/widgets/app_top_bar.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_theme.dart';

/// Barra de cabeçalho padronizada para páginas de formulário. Delega o **layout
/// e o estilo** à barre standard [AppTopBar] (fond distinct + ombre, tokens dans
/// le thème) et se combine avec [FormHeaderActions] pour les actions CRUD.
class FormPageHeader extends StatelessWidget {
  final String title;

  /// Ícone ou botão à esquerda do título (ex: botão voltar).
  final Widget? leading;

  /// Widget à direita do título (ex: botão "Finaliser").
  final Widget? trailing;

  const FormPageHeader({
    super.key,
    required this.title,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return AppTopBar(title: title, leading: leading, trailing: trailing);
  }
}

/// Actions standard du header d'un écran d'édition (CRUD), **toujours dans le
/// même ordre** : **Enregistrer** (vert, `saveButtonStyle`) · **Fermer** (bordé,
/// `cancelButtonStyle`) · — séparateur — · [extraActions] (ex. « Finaliser »).
/// À passer dans `FormPageHeader.trailing`.
///
/// - [onSave] : action du bouton Enregistrer (null = désactivé).
/// - [onClose] : action du bouton Fermer.
/// - [isSaving] : affiche un spinner sur Enregistrer et désactive les boutons.
/// - [saveLabel] : libellé du bouton Enregistrer (défaut « Enregistrer »).
/// - [extraActions] : boutons additionnels après Fermer, séparés par un trait
///   vertical (ex. « Finaliser »).
/// - [closeLabel] : libellé du bouton de fermeture (défaut « Fermer »).
class FormHeaderActions extends StatelessWidget {
  final VoidCallback? onSave;
  final VoidCallback onClose;
  final bool isSaving;
  final String saveLabel;
  final List<Widget> extraActions;
  final String closeLabel;

  const FormHeaderActions({
    super.key,
    required this.onClose,
    this.onSave,
    this.isSaving = false,
    this.saveLabel = 'Enregistrer',
    this.extraActions = const [],
    this.closeLabel = 'Fermer',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onSave != null) ...[
          FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            style: AppTheme.saveButtonStyle,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined, size: 18),
            label: Text(saveLabel),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        OutlinedButton.icon(
          onPressed: isSaving ? null : onClose,
          style: AppTheme.cancelButtonStyle,
          icon: const Icon(Icons.close, size: 18),
          label: Text(closeLabel),
        ),
        if (extraActions.isNotEmpty) ...[
          const SizedBox(width: AppSpacing.md),
          // Séparateur vertical avant les actions secondaires (ex. Finaliser).
          Container(
            width: 1,
            height: 28,
            color: AppColors.outlineVariant,
          ),
          const SizedBox(width: AppSpacing.md),
          for (var i = 0; i < extraActions.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.sm),
            extraActions[i],
          ],
        ],
      ],
    );
  }
}
