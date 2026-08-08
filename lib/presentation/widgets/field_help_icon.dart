import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_colors.dart';

/// Petite icône « ? » (point d'interrogation) affichant une bulle d'aide au
/// survol / appui long. À placer dans `InputDecoration.suffixIcon` pour
/// expliquer à quoi sert un champ. Source unique du style.
Widget fieldHelpIcon(String message) {
  return Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.tap,
    showDuration: const Duration(seconds: 6),
    margin: const EdgeInsets.symmetric(horizontal: 24),
    child: Icon(
      Icons.help_outline,
      size: 18,
      color: AppColors.onSurfaceVariant,
    ),
  );
}
