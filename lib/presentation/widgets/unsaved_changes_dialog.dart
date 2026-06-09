import 'package:flutter/material.dart';

/// Choix de l'utilisateur dans la boîte « modifications non sauvegardées ».
enum UnsavedChoice {
  /// Rester sur l'écran (ne pas quitter).
  cancel,

  /// Quitter sans sauvegarder.
  discard,

  /// Sauvegarder puis quitter.
  save,
}

/// Boîte de dialogue réutilisable de confirmation de sortie d'un écran
/// d'édition (« Continuer / Quitter sans sauvegarder / Sauvegarder et quitter »).
///
/// COMMENT L'UTILISER :
/// ```dart
/// Future<void> _handleBack() async {
///   if (!isDirty) { _leave(); return; }            // rien à confirmer
///   final choice = await showUnsavedChangesDialog(context);
///   switch (choice) {
///     case UnsavedChoice.cancel:  return;           // reste
///     case UnsavedChoice.discard: _leave();         // quitte sans sauver
///     case UnsavedChoice.save:    await _save(); _leave();
///   }
/// }
/// ```
///
/// Paramètres (tous optionnels — textes par défaut en français) :
/// - [title] / [message] : titre et corps de la boîte.
/// - [continueLabel] : bouton « rester » (retourne [UnsavedChoice.cancel]).
/// - [discardLabel] : bouton « quitter sans sauvegarder » ([UnsavedChoice.discard]).
/// - [saveLabel] : bouton « sauvegarder et quitter » ([UnsavedChoice.save]).
/// - [barrierDismissible] : si true (défaut), un tap en dehors = [UnsavedChoice.cancel].
///
/// Retourne toujours une valeur ([UnsavedChoice.cancel] si la boîte est fermée
/// sans choix), jamais null — l'appelant n'a pas à gérer le cas nul.
Future<UnsavedChoice> showUnsavedChangesDialog(
  BuildContext context, {
  String title = 'Modifications non sauvegardées',
  String message =
      'Vous avez des modifications non sauvegardées. Que souhaitez-vous faire ?',
  String continueLabel = 'Continuer',
  String discardLabel = 'Quitter sans sauvegarder',
  String saveLabel = 'Sauvegarder et quitter',
  bool barrierDismissible = true,
}) async {
  final result = await showDialog<UnsavedChoice>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, UnsavedChoice.cancel),
          child: Text(continueLabel),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, UnsavedChoice.discard),
          child: Text(discardLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, UnsavedChoice.save),
          child: Text(saveLabel),
        ),
      ],
    ),
  );
  return result ?? UnsavedChoice.cancel;
}
