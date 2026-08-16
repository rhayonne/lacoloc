import 'package:flutter/material.dart';
import 'package:habitafrance/presentation/nav/app_sidebar.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Entrée de navigation : soit une **feuille** (onTap), soit un **groupe**
/// (children non vides). Un groupe, une fois sélectionné, ouvre son contenu par
/// défaut ET affiche ses sous-menus (avec trait vertical reliant le groupe au
/// sous-menu sélectionné).
class NavEntry {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final List<NavChild> children;

  const NavEntry({
    required this.icon,
    required this.label,
    required this.onTap,
    this.count = 0,
    this.selected = false,
    this.children = const [],
  });

  bool get isGroup => children.isNotEmpty;
}

class NavChild {
  final String label;
  final bool selected;
  final int count;
  final VoidCallback onTap;

  /// Icône du sous-menu, **visible quand la barre est repliée** : c'est le seul
  /// moyen de savoir où l'on se trouve une fois les libellés masqués. Sans
  /// elle, un groupe replié affichait uniquement son icône de groupe et
  /// l'utilisateur perdait le niveau où il était.
  final IconData? icon;

  const NavChild({
    required this.label,
    required this.onTap,
    this.selected = false,
    this.count = 0,
    this.icon,
  });

  /// Icône à afficher, avec un repli déduit du libellé quand l'appelant n'en
  /// fournit pas — il vaut mieux une icône approximative que rien du tout.
  IconData get effectiveIcon => icon ?? _iconeDepuisLibelle(label);
}

/// Association libellé → icône pour les sous-menus qui n'en déclarent pas.
/// Volontairement courte : elle couvre les intitulés réellement utilisés dans
/// l'app, et retombe sur une icône neutre au lieu d'inventer.
IconData _iconeDepuisLibelle(String label) {
  final l = label.toLowerCase();
  if (l.contains('thème')) return Icons.palette_outlined;
  if (l.contains('email') || l.contains('e-mail')) return Icons.mail_outlined;
  if (l.contains('groupe')) return Icons.groups_outlined;
  if (l.contains('utilisateur')) return Icons.people_outlined;
  if (l.contains('message') || l.contains('discussion')) {
    return Icons.chat_bubble_outline;
  }
  if (l.contains('historique')) return Icons.history;
  if (l.contains('connexion')) return Icons.login_outlined;
  if (l.contains('service')) return Icons.build_outlined;
  if (l.contains('meuble')) return Icons.chair_outlined;
  if (l.contains('catégorie')) return Icons.category_outlined;
  if (l.contains('charge')) return Icons.receipt_long_outlined;
  if (l.contains('propriété') || l.contains('immeuble')) {
    return Icons.apartment_outlined;
  }
  if (l.contains('chambre')) return Icons.bed_outlined;
  if (l.contains('inventaire')) return Icons.inventory_2_outlined;
  if (l.contains('lot')) return Icons.grid_view_outlined;
  if (l.contains('entrée')) return Icons.login_outlined;
  if (l.contains('sortie')) return Icons.logout_outlined;
  if (l.contains('vétusté')) return Icons.trending_down;
  if (l.contains('générale') || l.contains('vision')) {
    return Icons.dashboard_outlined;
  }
  if (l.contains('recette')) return Icons.payments_outlined;
  if (l.contains('facture') || l.contains('dépense')) {
    return Icons.receipt_outlined;
  }
  if (l.contains('bail') || l.contains('baux')) return Icons.description_outlined;
  if (l.contains('signature')) return Icons.draw_outlined;
  if (l.contains('garant')) return Icons.shield_outlined;
  return Icons.subdirectory_arrow_right;
}

const double _childRowH = 40;

/// Barre latérale personnalisée gérant les **sous-menus** (ce que sidebarx ne
/// sait pas faire). Réutilise l'en-tête / le bouton de repli existants
/// ([sidebarHeaderWidget] / [sidebarCollapseButton]). Repliée (64 px) : icônes
/// seules + **tooltip** du libellé au survol.
class AppNavSidebar extends StatelessWidget {
  final SidebarXController controller;
  final List<NavEntry> entries;
  final String? userEmail;
  final String? userTypeLabel;
  final TextEditingController? searchController;
  final Widget Function(BuildContext, bool extended)? footerBuilder;
  final bool showToggleButton;

  const AppNavSidebar({
    super.key,
    required this.controller,
    required this.entries,
    this.userEmail,
    this.userTypeLabel,
    this.searchController,
    this.footerBuilder,
    this.showToggleButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final extended = controller.extended;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: extended ? 240 : 64,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            border:
                Border(right: BorderSide(color: AppColors.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sidebarHeaderWidget(
                extended: extended,
                email: userEmail,
                typeLabel: userTypeLabel,
                searchCtrl: searchController,
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final e in entries)
                        _NavEntryTile(
                          entry: e,
                          extended: extended,
                          onExpandSidebar: () => controller.setExtended(true),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              if (footerBuilder != null) footerBuilder!(context, extended),
              if (showToggleButton) ...[
                const Divider(height: 1, indent: 12, endIndent: 12),
                const SizedBox(height: 4),
                sidebarCollapseButton(
                    controller: controller, extended: extended),
                const SizedBox(height: 4),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NavEntryTile extends StatelessWidget {
  final NavEntry entry;
  final bool extended;
  final VoidCallback onExpandSidebar;
  const _NavEntryTile({
    required this.entry,
    required this.extended,
    required this.onExpandSidebar,
  });

  @override
  Widget build(BuildContext context) {
    // Un groupe est « ouvert » (children visibles) quand il est sélectionné et
    // que la barre est dépliée.
    final showChildren = extended && entry.isGroup && entry.selected;

    // Groupe sélectionné + déplié : bloc avec fond, en-tête + sous-menus.
    if (showChildren) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Container(
          decoration: BoxDecoration(
            // Fond du groupe entier (token thème).
            color: AppColors.navGroupBackground,
            borderRadius: AppRadius.borderMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _NavRow(
                icon: entry.icon,
                label: entry.label,
                selected: false, // fond fourni par le conteneur du groupe
                highlight: true,
                count: entry.count,
                extended: extended,
                noOuterMargin: true,
                trailing: Icon(Icons.expand_less,
                    size: 18, color: AppColors.primary),
                onTap: entry.onTap,
              ),
              _NavChildren(children: entry.children),
              const SizedBox(height: 4),
            ],
          ),
        ),
      );
    }

    // Groupe sélectionné mais barre repliée : on montre l'icône du groupe ET
    // celle du sous-menu courant. Sans ce second niveau, replier la barre
    // effaçait l'information « où suis-je », alors que c'est justement l'état
    // dans lequel on a le moins de repères.
    if (!extended && entry.isGroup && entry.selected) {
      final courant = entry.children.where((c) => c.selected).firstOrNull;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _NavRow(
            icon: entry.icon,
            label: entry.label,
            selected: false,
            highlight: true,
            count: entry.count,
            extended: false,
            onTap: () {
              onExpandSidebar();
              entry.onTap();
            },
          ),
          if (courant != null)
            _NavRow(
              icon: courant.effectiveIcon,
              label: '${entry.label} · ${courant.label}',
              selected: true,
              highlight: true,
              count: courant.count,
              extended: false,
              dense: true,
              onTap: courant.onTap,
            ),
        ],
      );
    }

    // Feuille, ou groupe replié / non sélectionné.
    return _NavRow(
      icon: entry.icon,
      label: entry.label,
      selected: entry.selected,
      highlight: entry.selected,
      count: entry.count,
      extended: extended,
      trailing: entry.isGroup && extended
          ? Icon(Icons.expand_more,
              size: 18, color: AppColors.onSurfaceVariant)
          : null,
      onTap: () {
        // Replié : on ouvre d'abord la barre pour révéler les sous-menus.
        if (entry.isGroup && !extended) onExpandSidebar();
        entry.onTap();
      },
    );
  }
}

/// Colonne des sous-menus avec l'arborescence : trait vertical (gris, coloré
/// jusqu'au sous-menu sélectionné) + tiret horizontal reliant chaque sous-menu.
class _NavChildren extends StatelessWidget {
  final List<NavChild> children;
  const _NavChildren({required this.children});

  @override
  Widget build(BuildContext context) {
    final selectedIdx = children.indexWhere((c) => c.selected);
    return CustomPaint(
      painter: _ConnectorPainter(
        count: children.length,
        selectedIdx: selectedIdx,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in children)
            SizedBox(height: _childRowH, child: _NavChildRow(child: c)),
        ],
      ),
    );
  }
}

/// Dessine le trait vertical + les tirets horizontaux de l'arborescence.
class _ConnectorPainter extends CustomPainter {
  final int count;
  final int selectedIdx;
  const _ConnectorPainter({required this.count, required this.selectedIdx});

  static const double _x = 20; // position du trait vertical
  static const double _dash = 12; // longueur du tiret horizontal

  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    final rowH = size.height / count;
    final gray = Paint()
      ..color = AppColors.navConnector
      ..strokeWidth = 1.5;
    final lit = Paint()
      ..color = AppColors.navConnectorActive
      ..strokeWidth = 1.5;

    // Trait vertical : s'arrête au centre du dernier sous-menu (au niveau de
    // son tiret horizontal) au lieu de descendre jusqu'en bas.
    final endY = (count - 0.5) * rowH;
    canvas.drawLine(const Offset(_x, 0), Offset(_x, endY), gray);
    // Portion colorée du haut jusqu'au centre du sous-menu sélectionné.
    if (selectedIdx >= 0) {
      final litY = (selectedIdx + 0.5) * rowH;
      canvas.drawLine(const Offset(_x, 0), Offset(_x, litY), lit);
    }
    // Tirets horizontaux (coloré pour le sélectionné).
    for (var i = 0; i < count; i++) {
      final cy = (i + 0.5) * rowH;
      canvas.drawLine(
          Offset(_x, cy), Offset(_x + _dash, cy), i == selectedIdx ? lit : gray);
    }
  }

  @override
  bool shouldRepaint(_ConnectorPainter old) =>
      old.selectedIdx != selectedIdx || old.count != count;
}

class _NavChildRow extends StatelessWidget {
  final NavChild child;
  const _NavChildRow({required this.child});

  @override
  Widget build(BuildContext context) {
    final selected = child.selected;
    return Padding(
      padding: const EdgeInsets.only(left: 36, right: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.borderMd,
        child: InkWell(
          onTap: child.onTap,
          borderRadius: AppRadius.borderMd,
          hoverColor: AppColors.navHover,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderMd,
              // Sous-menu sélectionné : teinte plus foncée que le fond du groupe.
              color: selected ? AppColors.navChildSelected : null,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    child.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMd.copyWith(
                      color:
                          selected ? AppColors.primary : AppColors.onSurface,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (child.count > 0) _MiniBadge(count: child.count),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool highlight;
  final int count;
  final bool extended;
  final Widget? trailing;
  final VoidCallback onTap;
  // En-tête d'un groupe : pas de marge horizontale (le conteneur du groupe la
  // fournit déjà) → alignement propre du fond.
  final bool noOuterMargin;

  /// Ligne de second niveau (sous-menu affiché barre repliée) : icône plus
  /// petite et hauteur réduite, pour se lire comme un enfant et non comme un
  /// menu de plus.
  final bool dense;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.selected,
    required this.highlight,
    required this.count,
    required this.extended,
    required this.onTap,
    this.trailing,
    this.noOuterMargin = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = (selected || highlight)
        ? AppColors.primary
        : AppColors.onSurfaceVariant;

    Widget iconW = Icon(icon, size: dense ? 16 : 20, color: color);
    if (count > 0) {
      iconW = Badge(
        label: Text(count > 99 ? '99+' : '$count'),
        backgroundColor: AppColors.error,
        textColor: Colors.white,
        child: iconW,
      );
    }

    final row = Padding(
      padding: EdgeInsets.symmetric(
          horizontal: noOuterMargin ? 0 : 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.borderMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderMd,
          hoverColor: AppColors.navHover,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: 8, vertical: dense ? 6 : 10),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderMd,
              color: selected ? AppColors.navItemSelected : null,
            ),
            child: extended
                ? Row(
                    children: [
                      iconW,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.bodyMd.copyWith(
                            color: (selected || highlight)
                                ? AppColors.primary
                                : AppColors.onSurface,
                            fontWeight: (selected || highlight)
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  )
                : Center(child: iconW),
          ),
        ),
      ),
    );

    if (extended) return row;
    return Tooltip(message: label, child: row);
  }
}

class _MiniBadge extends StatelessWidget {
  final int count;
  const _MiniBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: AppRadius.borderFull,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: AppTypography.labelSm.copyWith(color: Colors.white),
      ),
    );
  }
}
