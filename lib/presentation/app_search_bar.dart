import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/models/chambre.dart';
import 'package:habitafrance/presentation/login_dialog.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/theme/app_button_sizes.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';

class AppSearchBar extends StatefulWidget implements PreferredSizeWidget {
  final List<ChambreModel> listCache;
  final ValueChanged<String> onSearch;
  final bool isExpanded;
  final VoidCallback onTap;
  final Widget? leading;

  const AppSearchBar({
    super.key,
    required this.listCache,
    required this.onSearch,
    required this.isExpanded,
    required this.onTap,
    this.leading,
  });

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();

  // Même hauteur que la boîte du logo dans `_SidebarHeader`
  // (`app_sidebar.dart`, `SizedBox(height: 64)`) — sinon la ligne du bas de
  // cette barre (ombre de l'AppBar) ne s'aligne pas avec le divider sous le
  // logo de la sidebar.
  static const double barHeight = 64;

  @override
  Size get preferredSize => const Size.fromHeight(barHeight);
}

class _AppSearchBarState extends State<AppSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // A barra cresce ao receber foco e volta ao tamanho padrão ao perdê-lo
    // (clique fora).
    _focusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLogged = AuthService.isLoggedIn;

    // O tamanho é dirigido pelo foco do campo (clique dentro → grande,
    // clique fora → padrão).
    final isExpanded = _focusNode.hasFocus;

    return AppBar(
      leading: widget.leading,
      toolbarHeight: AppSearchBar.barHeight,
      elevation: 3,
      scrolledUnderElevation: 0,
      surfaceTintColor: AppColors.surfaceContainer,
      shadowColor: Colors.blue,
      // LayoutBuilder mede a largura REAL disponível para o titre (não a
      // largura da janela via MediaQuery) — a sidebar pode consumir parte
      // da tela em desktop, então usar MediaQuery aqui subestimaria/
      // superestimaria o espaço disponível.
      title: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 600;
          final expandedWidth = isWide ? 560.0 : 400.0;
          final collapsedWidth = isWide ? 320.0 : 220.0;
          final maxAvailable = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : double.infinity;
          final targetWidth = isExpanded ? expandedWidth : collapsedWidth;
          final width = maxAvailable.isFinite
              ? targetWidth.clamp(0.0, maxAvailable)
              : targetWidth;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            width: width,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppRadius.borderFull,
              border: Border.all(color: AppColors.outlineVariant),
              boxShadow: [
                if (isExpanded)
                  BoxShadow(
                    color: AppColors.shadowTint.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onTap: widget.onTap,
              onChanged: (value) {
                setState(() => _searchQuery = value);
                widget.onSearch(value);
              },
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 16,
                ),
                prefixIcon: _searchQuery.isEmpty
                    ? const Icon(Icons.search, size: 20)
                    : null,
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Effacer la recherche',
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                          widget.onSearch('');
                        },
                      )
                    : null,
              ),
            ),
          );
        },
      ),
      actions: [
        // Bouton compact (44pt, iOS HIG) : en taille standard (48) + padding, il
        // débordait la barre (56px) et le libellé chevauchait l'icône. La taille
        // compacte tient dans la toolbar. Widget réutilisable [AppButton].
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.xs,
            bottom: AppSpacing.xs,
            left: AppSpacing.sm,
            right: AppSpacing.md,
          ),
          child: AppButton.primary(
            size: AppButtonSize.compact,
            icon: isLogged ? Icons.account_circle : Icons.login,
            label: isLogged ? 'Mon compte' : 'Connexion',
            onPressed: () {
              if (isLogged) {
                Navigator.of(context).pushNamed('/profile');
              } else {
                showConnexionDialog(context);
              }
            },
          ),
        ),
      ],
    );
  }
}
