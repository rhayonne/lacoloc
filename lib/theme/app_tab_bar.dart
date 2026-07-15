import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_colors.dart';

/// Barre d'onglets **standard** du système, au look « groupe de boutons »
/// (segmented control) : les onglets sont posés sur une **piste** (fond clair +
/// bord + coins arrondis) pour qu'ils se lisent clairement comme des boutons et
/// non comme une simple ligne de mots.
///
/// La **pastille** de l'onglet actif (teal, libellé blanc) et les couleurs de
/// libellé viennent du thème global (`tabBarTheme` dans
/// [AppTheme.light] — voir `lib/theme/app_theme.dart`). Ici on n'ajoute que la
/// piste et l'espacement ; changer l'apparence des onglets partout = éditer le
/// `tabBarTheme` (couleurs/pastille) et/ou ce widget (piste).
///
/// À utiliser **partout** à la place de `TabBar` (tous les profils). Implémente
/// [PreferredSizeWidget] pour pouvoir servir de `AppBar.bottom` également.
class AppTabBar extends StatelessWidget implements PreferredSizeWidget {
  final TabController? controller;
  final List<Widget> tabs;
  final bool isScrollable;

  const AppTabBar({
    super.key,
    this.controller,
    required this.tabs,
    this.isScrollable = false,
  });

  static const double _height = 52;

  @override
  Size get preferredSize => const Size.fromHeight(_height);

  @override
  Widget build(BuildContext context) {
    return Container(
      // Piste = « groupe de boutons » : fond léger, bord fin, coins arrondis.
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: TabBar(
        controller: controller,
        isScrollable: isScrollable,
        // Non défilable → les onglets se partagent la largeur (vrais boutons) ;
        // défilable → alignés à gauche et défilent.
        tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
        // La pastille (indicateur), les couleurs et le retrait du trait natif
        // viennent du thème global (`tabBarTheme`).
        splashBorderRadius: BorderRadius.circular(8),
        tabs: tabs,
      ),
    );
  }
}
