import 'package:flutter/material.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:sidebarx/sidebarx.dart';

export 'package:sidebarx/sidebarx.dart' show SidebarXController, SidebarXItem;

/// Sidebar compartilhada do app, baseada no pacote sidebarx.
///
/// Responsividade:
/// - Em telas largas (>= 800 px) → aparece como painel lateral fixo.
/// - Em telas estreitas (< 800 px) → o pai deve usá-la como [Scaffold.drawer].
///
/// [items]: itens de navegação principal.
/// [footerBuilder]: widget abaixo do divider inferior (ex.: botão logout).
/// [userEmail]: exibido no cabeçalho quando expandida.
/// [searchController]: exibe campo de pesquisa no cabeçalho quando não nulo.
/// [showToggleButton]: false ao usar em modo drawer (tela estreita).
class AppSidebar extends StatelessWidget {
  final SidebarXController controller;
  final List<SidebarXItem> items;
  final String? userEmail;
  final TextEditingController? searchController;
  final Widget Function(BuildContext, bool extended)? footerBuilder;
  final bool showToggleButton;

  const AppSidebar({
    super.key,
    required this.controller,
    required this.items,
    this.userEmail,
    this.searchController,
    this.footerBuilder,
    this.showToggleButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return SidebarX(
      controller: controller,
      showToggleButton: showToggleButton,
      animationDuration: const Duration(milliseconds: 220),
      // Tema compacto (ícones apenas, 64 px)
      theme: SidebarXTheme(
        width: 64,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(right: BorderSide(color: AppColors.outlineVariant)),
        ),
        iconTheme: const IconThemeData(
          color: AppColors.onSurfaceVariant,
          size: 20,
        ),
        selectedIconTheme: const IconThemeData(
          color: AppColors.primary,
          size: 20,
        ),
        hoverColor: AppColors.surfaceContainerLow,
        itemMargin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        itemDecoration: BoxDecoration(borderRadius: AppRadius.borderMd),
        selectedItemDecoration: BoxDecoration(
          color: AppColors.primaryFixed.withValues(alpha: 0.45),
          borderRadius: AppRadius.borderMd,
        ),
      ),
      // Tema expandido (ícones + rótulos, 240 px) — funde com o tema compacto
      extendedTheme: SidebarXTheme(
        width: 240,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(right: BorderSide(color: AppColors.outlineVariant)),
        ),
        textStyle: AppTypography.bodyMd.copyWith(color: AppColors.onSurface),
        selectedTextStyle: AppTypography.bodyMd.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
        itemTextPadding: const EdgeInsets.only(left: 12),
        selectedItemTextPadding: const EdgeInsets.only(left: 12),
      ),
      headerBuilder: (context, extended) => _SidebarHeader(
        extended: extended,
        email: userEmail,
        searchCtrl: searchController,
      ),
      headerDivider: const Divider(height: 1),
      footerDivider: footerBuilder != null ? const Divider(height: 1) : null,
      footerBuilder: footerBuilder,
      items: items,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  final bool extended;
  final String? email;
  final TextEditingController? searchCtrl;

  const _SidebarHeader({required this.extended, this.email, this.searchCtrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Logo
        SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: extended
                ? Row(
                    children: [
                      const SizedBox(width: AppSpacing.xs),
                      const _AppLogoFull(),
                    ],
                  )
                : const Center(child: _AppLogoIcon()),
          ),
        ),
        // Info do utilizador (apenas expandido)
        if (email != null && extended)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              0,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryFixed,
                  child: const Icon(
                    Icons.person,
                    color: AppColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    email!,
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        // Barra de pesquisa (apenas expandido + controller presente)
        if (searchCtrl != null && extended)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: AnimatedBuilder(
                    animation: searchCtrl!,
                    builder: (_, _) => TextField(
                      controller: searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Rechercher…',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: searchCtrl!.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: searchCtrl!.clear,
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message:
                      'Recherchez dans tout votre espace :\nimmeubles, chambres, locataires…',
                  triggerMode: TooltipTriggerMode.tap,
                  preferBelow: false,
                  child: Icon(
                    Icons.help_outline,
                    size: 18,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else if (email != null && extended)
          const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AppLogoFull extends StatelessWidget {
  const _AppLogoFull();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AppLogoIcon(),
        const SizedBox(width: AppSpacing.sm),
        Text(
          'Super Coloc',
          style: AppTypography.titleLg.copyWith(color: AppColors.primary),
        ),
      ],
    );
  }
}

class _AppLogoIcon extends StatelessWidget {
  const _AppLogoIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.borderSm,
      ),
      child: const Icon(Icons.home_work, color: AppColors.onPrimary, size: 16),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Botão de ação no footer da sidebar (logout, connexion, etc.).
/// Adapta-se ao modo expandido/compacto.
class SidebarActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool extended;

  const SidebarActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    required this.extended,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurfaceVariant;
    return Tooltip(
      message: extended ? '' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderMd,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: extended
              ? Row(
                  children: [
                    Icon(icon, color: c, size: 20),
                    const SizedBox(width: 12),
                    Text(label, style: AppTypography.bodyMd.copyWith(color: c)),
                  ],
                )
              : Center(child: Icon(icon, color: c, size: 20)),
        ),
      ),
    );
  }
}
