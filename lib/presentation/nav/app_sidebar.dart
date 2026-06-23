import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/auth_service.dart';
import 'package:lacoloc_front/theme/app_colors.dart';
import 'package:lacoloc_front/theme/app_radius.dart';
import 'package:lacoloc_front/theme/app_spacing.dart';
import 'package:lacoloc_front/theme/app_typography.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:url_launcher/url_launcher.dart';

export 'package:sidebarx/sidebarx.dart' show SidebarXController, SidebarXItem;

/// Crée un [SidebarXItem] standard du menu :
/// - pastille (badge) avec [count] quand `count > 0` (« nouveau / à traiter ») ;
/// - **tooltip** avec le libellé quand la barre est repliée ([extended] = false),
///   pour que le nom de chaque menu reste accessible une fois la barre réduite.
/// Réutilise `iconBuilder` du paquet sidebarx pour personnaliser l'icône.
SidebarXItem badgedSidebarItem({
  required IconData icon,
  required String label,
  int count = 0,
  bool extended = true,
}) {
  return SidebarXItem(
    label: label,
    iconBuilder: (selected, hovered) {
      final color = selected ? AppColors.primary : AppColors.onSurfaceVariant;
      Widget child = Icon(icon, size: 20, color: color);
      if (count > 0) {
        child = Badge(
          label: Text(count > 99 ? '99+' : '$count'),
          backgroundColor: AppColors.error,
          textColor: Colors.white,
          child: child,
        );
      }
      // Tooltip seulement quand replié (sinon le libellé est déjà visible).
      // On évite un Tooltip à message vide (déplié) qui peut boucler l'overlay.
      if (extended) return child;
      return Tooltip(message: label, child: child);
    },
  );
}

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
  /// Libellé du type d'utilisateur affiché sous l'e-mail (ex. « Propriétaire »,
  /// « Admin entreprise »). Null = non affiché.
  final String? userTypeLabel;
  final TextEditingController? searchController;
  final Widget Function(BuildContext, bool extended)? footerBuilder;
  final bool showToggleButton;

  const AppSidebar({
    super.key,
    required this.controller,
    required this.items,
    this.userEmail,
    this.userTypeLabel,
    this.searchController,
    this.footerBuilder,
    this.showToggleButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return SidebarX(
      controller: controller,
      // Bouton de repli natif désactivé : on en rend un personnalisé (libellé +
      // bordure) dans le footer pour mieux le signaler.
      showToggleButton: false,
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
        typeLabel: userTypeLabel,
        searchCtrl: searchController,
      ),
      headerDivider: const Divider(height: 1),
      footerDivider: const Divider(height: 1),
      footerBuilder: (context, extended) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (footerBuilder != null) footerBuilder!(context, extended),
          if (showToggleButton) ...[
            const Divider(height: 1, indent: 12, endIndent: 12),
            const SizedBox(height: 4),
            _SidebarCollapseButton(controller: controller, extended: extended),
            const SizedBox(height: 4),
          ],
        ],
      ),
      items: items,
    );
  }
}

/// Bouton de repli/agrandissement de la barre latérale (remplace le toggle natif
/// de sidebarx). Étendu : libellé « Réduire le menu » + chevron, dans un cadre
/// bordé ; replié : chevron centré bordé. Tooltip quand replié.
class _SidebarCollapseButton extends StatelessWidget {
  final SidebarXController controller;
  final bool extended;
  const _SidebarCollapseButton({required this.controller, required this.extended});

  @override
  Widget build(BuildContext context) {
    final btn = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.borderMd,
          child: InkWell(
            onTap: () => controller.setExtended(!extended),
            borderRadius: AppRadius.borderMd,
            hoverColor: AppColors.surfaceContainerLow,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: extended
                  ? _CollapseClip(
                      minWidth: 100,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chevron_left,
                              size: 20, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'Réduire le menu',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMd
                                  .copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.chevron_right,
                          size: 20, color: AppColors.onSurfaceVariant),
                    ),
            ),
          ),
        ),
      );
    // Tooltip seulement quand replié (évite un Tooltip à message vide).
    if (extended) return btn;
    return Tooltip(message: 'Agrandir le menu', child: btn);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Évite les RenderFlex overflow pendant l'animation d'ouverture/fermeture de la
/// sidebar (largeur animée 64 ↔ 240) : pendant que le conteneur est plus étroit
/// que [minWidth], on masque le contenu « étendu » (qui ne tiendrait pas) ; au-
/// dessus, on l'affiche (ses enfants Expanded/Flexible s'ajustent) sous un
/// [ClipRect] de sécurité. N'utilise aucun box dimensionné par le parent
/// (pas d'OverflowBox) → pas d'assertion de contrainte même en largeur non bornée.
class _CollapseClip extends StatelessWidget {
  final double minWidth;
  final Widget child;
  const _CollapseClip({required this.child, this.minWidth = 0});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isFinite && constraints.maxWidth < minWidth) {
          return const SizedBox.shrink();
        }
        return ClipRect(child: child);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SidebarHeader extends StatelessWidget {
  final bool extended;
  final String? email;
  final String? typeLabel;
  final TextEditingController? searchCtrl;

  const _SidebarHeader({
    required this.extended,
    this.email,
    this.typeLabel,
    this.searchCtrl,
  });

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
                ? const Center(child: _AppLogoFull())
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
            child: _CollapseClip(
              minWidth: 44,
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          email!,
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Type d'utilisateur sous l'e-mail (badge discret).
                        if (typeLabel != null && typeLabel!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              typeLabel!,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Botão do manual — só para utilizador autenticado (não aparece na
        // home pública / detalhe de chambre quando deslogado).
        if (extended && AuthService.isLoggedIn)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
            child: _CollapseClip(
              minWidth: 80,
              child: _ManualButton(),
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
            child: _CollapseClip(
              minWidth: 60,
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
            ),
          )
        else if (email != null && extended)
          const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Botão « Manuel utilisateur » com animação shimmer na primeira vez que a
/// sidebar é expandida (uma única passagem branca da esquerda para a direita).
class _ManualButton extends StatefulWidget {
  const _ManualButton();

  @override
  State<_ManualButton> createState() => _ManualButtonState();
}

class _ManualButtonState extends State<_ManualButton>
    with SingleTickerProviderStateMixin {
  // Flag de sessão: o shimmer só toca uma vez por sessão de app.
  static bool _shimmerPlayed = false;

  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // Valor vai de -1 (fora à esquerda) a 2 (fora à direita).
    _shimmer = Tween<double>(begin: -1, end: 2).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    if (!_shimmerPlayed) {
      // Pequeno atraso para a sidebar terminar de abrir antes do shimmer.
      Future.delayed(const Duration(milliseconds: 280), () {
        if (mounted) {
          _ctrl.forward().whenComplete(() {
            _shimmerPlayed = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    // Em web: abre /manual/index.html numa nova aba.
    final base = Uri.base;
    final url = base.replace(
      path: '/manual/index.html',
      query: '',
      fragment: '',
    );
    launchUrl(url, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Manuel utilisateur',
      child: InkWell(
        onTap: _open,
        borderRadius: AppRadius.borderMd,
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (context, child) {
            return ClipRRect(
              borderRadius: AppRadius.borderMd,
              child: CustomPaint(
                foregroundPainter: _shimmerPlayed
                    ? null
                    : _ShimmerPainter(progress: _shimmer.value),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed.withValues(alpha: 0.35),
              borderRadius: AppRadius.borderMd,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.menu_book_outlined,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    'Manuel utilisateur',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.open_in_new,
                    size: 12,
                    color: AppColors.primary.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pinta o efeito shimmer: um feixe branco semi-transparente que varre da
/// esquerda para a direita uma única vez. [progress] vai de -1 a 2.
class _ShimmerPainter extends CustomPainter {
  final double progress;
  const _ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress < -0.5 || progress > 1.5) return;
    final w = size.width;
    final center = progress * w;
    const beamW = 60.0;
    final rect = Rect.fromLTWH(0, 0, w, size.height);
    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.55),
        Colors.white.withValues(alpha: 0),
      ],
      stops: [
        math.max(0, (center - beamW / 2) / w),
        (center / w).clamp(0.0, 1.0),
        math.min(1, (center + beamW / 2) / w),
      ],
    );
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────────────────────────────────────────

class _AppLogoFull extends StatelessWidget {
  const _AppLogoFull();

  @override
  Widget build(BuildContext context) {
    // Le texte est `Flexible` + ellipsis : pendant l'animation de
    // collapse/expand de la sidebar, la largeur disponible peut tomber à ~47 px
    // alors que le logo complet est encore rendu — sans ça, ça déborde.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const _AppLogoIcon(),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            'Super Loc',
            style: AppTypography.titleLg.copyWith(color: AppColors.primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
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
    final btn = Padding(
      // Même marge que les items de menu pour aligner le hover.
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.borderMd,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.borderMd,
          hoverColor: AppColors.surfaceContainerLow,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: extended
                // _CollapseClip masque la ligne pendant l'animation de
                // fermeture (largeur < minWidth) → pas d'overflow de 1 px.
                ? _CollapseClip(
                    minWidth: 100,
                    // Center → le groupe (icône + libellé) reste centré
                    // horizontalement, cohérent avec « Accueil ».
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(icon, color: c, size: 20),
                          const SizedBox(width: 12),
                          // Flexible → le libellé s'adapte à la largeur dispo
                          // (y compris pendant l'animation d'ouverture/fermeture)
                          // et passe sur 2 lignes si besoin, sans overflow.
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 2,
                              softWrap: true,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMd.copyWith(color: c),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(child: Icon(icon, color: c, size: 20)),
          ),
        ),
      ),
    );
    // Tooltip seulement quand replié (évite un Tooltip à message vide).
    if (extended) return btn;
    return Tooltip(message: label, child: btn);
  }
}
