import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/presentation/login_dialog.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';

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

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
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

    // Em tablet/desktop (≥ 600px) a barra fica ~40% mais larga.
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    final expandedWidth = isWide ? 560.0 : 400.0;
    final collapsedWidth = isWide ? 320.0 : 220.0;

    // O tamanho é dirigido pelo foco do campo (clique dentro → grande,
    // clique fora → padrão).
    final isExpanded = _focusNode.hasFocus;

    return AppBar(
      leading: widget.leading,
      elevation: 3,
      scrolledUnderElevation: 0,
      surfaceTintColor: AppColors.surfaceContainer,
      shadowColor: Colors.blue,
      title: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: isExpanded ? expandedWidth : collapsedWidth,
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
      ),
      actions: [
        // IconButton(
        //   icon: const Icon(Icons.search_outlined),
        //   onPressed: () {
        //     showSearch(
        //       context: context,
        //       delegate: SearchDelgateTobar(chambres: widget.listCache),
        //     );
        //   },
        // ),
        Padding(
          padding: const EdgeInsets.only(
            top: AppSpacing.sm,
            bottom: AppSpacing.sm,
            left: AppSpacing.sm,
            right: AppSpacing.lg,
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              if (isLogged) {
                Navigator.of(context).pushNamed('/profile');
              } else {
                showConnexionDialog(context);
              }
            },
            icon: Icon(isLogged ? Icons.account_circle : Icons.login, size: 18),
            label: Text(isLogged ? 'Mon compte' : 'Connexion'),
          ),
        ),
      ],
    );
  }
}
