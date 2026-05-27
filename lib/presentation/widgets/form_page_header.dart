import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';

/// Barra de cabeçalho padronizada para todas as páginas de formulário.
/// Apresenta sombra suave que a eleva visualmente acima do conteúdo.
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowTint.withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Text(title, style: AppTypography.titleLg),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
