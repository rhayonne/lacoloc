import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/data/models/chambre.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/utils/search_delegate_tobar.dart';

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
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isLogged = AuthService.isLoggedIn;

    return AppBar(
      leading: widget.leading,
      title: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        width: widget.isExpanded ? 400 : 220,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppRadius.borderFull,
          border: Border.all(color: AppColors.outlineVariant),
          boxShadow: [
            if (widget.isExpanded)
              BoxShadow(
                color: AppColors.shadowTint.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: TextField(
          controller: _searchController,
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
        IconButton(
          icon: const Icon(Icons.search_outlined),
          onPressed: () {
            showSearch(
              context: context,
              delegate: SearchDelgateTobar(chambres: widget.listCache),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.sm,
          ),
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pushNamed(isLogged ? '/profile' : '/login');
            },
            icon: Icon(
              isLogged ? Icons.account_circle : Icons.login,
              size: 18,
            ),
            label: Text(isLogged ? 'Mon compte' : 'Connexion'),
          ),
        ),
      ],
    );
  }
}
