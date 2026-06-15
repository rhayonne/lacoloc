import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_theme.dart';

/// Bouton standard « Document » (génération / impression PDF) de l'app.
///
/// À utiliser **partout** où l'on propose une impression / un export PDF, afin
/// d'avoir une apparence cohérente (icône PDF + libellé, style
/// [AppTheme.documentButtonStyle]).
///
/// Exemples : header des EDL (`FormHeaderActions.extraActions`), fiche en
/// lecture seule, etc.
class DocumentPdfButton extends StatelessWidget {
  /// Action déclenchée au clic (ouvre généralement la prévisualisation PDF).
  final VoidCallback? onPressed;

  /// Libellé du bouton (par défaut « Document »).
  final String label;

  /// Variante compacte (icône seule, sans libellé) — utile dans une AppBar.
  final bool iconOnly;

  /// Info-bulle (surtout utile en mode [iconOnly]).
  final String? tooltip;

  const DocumentPdfButton({
    super.key,
    required this.onPressed,
    this.label = 'Document',
    this.iconOnly = false,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    if (iconOnly) {
      return IconButton(
        onPressed: onPressed,
        icon: const Icon(Icons.picture_as_pdf_outlined),
        tooltip: tooltip ?? label,
        color: Theme.of(context).colorScheme.primary,
      );
    }
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: AppTheme.documentButtonStyle,
      icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
      label: Text(label),
    );
  }
}
