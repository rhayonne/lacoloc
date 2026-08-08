import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_theme.dart';

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

/// Variante « Document » avec **choix** entre plusieurs documents (EDL / Bail).
///
/// Ouvre un **popover** ancré sous le bouton (`MenuAnchor` — se ferme au clic
/// dehors, suit le bouton, responsive). Même style que [DocumentPdfButton].
/// Utilisé dans le header des EDL où l'on peut imprimer l'état des lieux OU le
/// bail. Si [onBail] est null, seule l'entrée « État des lieux » est proposée.
class DocumentChoiceButton extends StatelessWidget {
  final VoidCallback onEdl;
  final VoidCallback? onBail;
  final String bailLabel;

  const DocumentChoiceButton({
    super.key,
    required this.onEdl,
    this.onBail,
    this.bailLabel = 'Bail',
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.assignment_outlined, size: 18),
          onPressed: onEdl,
          child: const Text('État des lieux'),
        ),
        if (onBail != null)
          MenuItemButton(
            leadingIcon: const Icon(Icons.description_outlined, size: 18),
            onPressed: onBail,
            child: Text(bailLabel),
          ),
      ],
      builder: (context, controller, child) => OutlinedButton.icon(
        style: AppTheme.documentButtonStyle,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Document'),
            SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 18),
          ],
        ),
      ),
    );
  }
}
