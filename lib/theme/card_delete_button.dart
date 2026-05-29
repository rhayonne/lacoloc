import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Bouton "corbeille" standard pour supprimer un élément à l'intérieur
/// d'une carte (chips locataires, lignes de liste, etc.).
///
/// Remplace les anciens « x » disséminés dans l'app : à utiliser partout
/// où une carte doit offrir une action de suppression discrète.
class CardDeleteButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String tooltip;
  final double iconSize;

  const CardDeleteButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Supprimer',
    this.iconSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(
            Icons.delete_outline,
            size: iconSize,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }
}
