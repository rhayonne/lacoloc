import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';

/// Barre de recherche standard pour filtrer des listes.
///
/// Utilisation :
/// ```dart
/// AppListSearchField(
///   hint: 'Rechercher par nom ou e-mail…',
///   onChanged: (q) => setState(() => _search = q),
/// )
/// ```
///
/// [onChanged] reçoit la valeur en minuscules, prête pour [String.contains].
class AppListSearchField extends StatelessWidget {
  final String hint;

  /// Appelé à chaque frappe avec la valeur en minuscules.
  final ValueChanged<String> onChanged;

  /// Padding autour du champ (défaut : horizontal xl).
  final EdgeInsetsGeometry? padding;

  /// Taille de l'icône de recherche (défaut : null = taille du thème).
  final double? iconSize;

  const AppListSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.padding,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: TextField(
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: iconSize != null
              ? Icon(Icons.search, size: iconSize)
              : const Icon(Icons.search),
          isDense: true,
        ),
        onChanged: (v) => onChanged(v.toLowerCase()),
      ),
    );
  }
}
