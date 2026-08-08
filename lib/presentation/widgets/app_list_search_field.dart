import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';

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
///
/// [controller] est optionnel : passez le vôtre si vous avez besoin de lire/
/// effacer le texte depuis l'extérieur (ex. un état `_query` existant) — un
/// bouton « Effacer » apparaît alors automatiquement dès qu'il y a du texte.
/// Sans [controller], le widget gère le sien en interne (comportement
/// inchangé pour les appels existants).
class AppListSearchField extends StatefulWidget {
  final String hint;

  /// Appelé à chaque frappe avec la valeur en minuscules.
  final ValueChanged<String> onChanged;

  /// Padding autour du champ (défaut : horizontal xl).
  final EdgeInsetsGeometry? padding;

  /// Taille de l'icône de recherche (défaut : null = taille du thème).
  final double? iconSize;

  /// Contrôleur externe optionnel (active le bouton « Effacer »).
  final TextEditingController? controller;

  const AppListSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.padding,
    this.iconSize,
    this.controller,
  });

  @override
  State<AppListSearchField> createState() => _AppListSearchFieldState();
}

class _AppListSearchFieldState extends State<AppListSearchField> {
  late final TextEditingController _ctrl;
  late final bool _ownsCtrl;

  @override
  void initState() {
    super.initState();
    _ownsCtrl = widget.controller == null;
    _ctrl = widget.controller ?? TextEditingController();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    if (_ownsCtrl) _ctrl.dispose();
    super.dispose();
  }

  void _clear() {
    _ctrl.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.borderMd,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _ctrl,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.iconSize != null
                ? Icon(Icons.search, size: widget.iconSize)
                : const Icon(Icons.search),
            suffixIcon: widget.controller != null && _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Effacer la recherche',
                    onPressed: _clear,
                  )
                : null,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 10,
            ),
          ),
          onChanged: (v) => widget.onChanged(v.toLowerCase()),
        ),
      ),
    );
  }
}
