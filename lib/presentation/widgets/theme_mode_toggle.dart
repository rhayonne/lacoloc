import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/auth_service.dart';
import 'package:habitafrance/data/models/theme_ref.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_palette.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_typography.dart';
import 'package:habitafrance/theme/theme_controller.dart';

/// Bouton **clair / sombre** du menu latéral.
///
/// ## Ce qu'il fait, et pourquoi c'est dit à la personne
///
/// Ce bouton n'est pas un interrupteur d'affichage temporaire : il **choisit
/// le thème par défaut** de la personne. C'est un effet durable, décidé par un
/// clic sur une icône — donc un message le dit explicitement à chaque bascule,
/// au lieu de laisser découvrir plus tard que « l'app est restée sombre ».
///
/// Le message change selon qu'une session est ouverte :
/// - **connecté** — le choix part sur le compte, donc il suit sur tous les
///   appareils ;
/// - **non connecté** — le choix reste sur cet appareil, et il sera **repris
///   sur le compte** à la connexion (c'est `AuthService.loadThemePreference`
///   qui s'en charge). On l'annonce, sinon la personne pourrait croire qu'elle
///   perdra son réglage en se connectant.
///
/// ## Disponible pour tout le monde
///
/// Le bouton vit dans les deux barres latérales (`AppSidebar` et
/// `AppNavSidebar`), donc dans **toutes** les coquilles de l'app — accueil
/// public compris. Un visiteur qui n'a pas de compte y a droit aussi.
///
/// Il se cache tout seul si aucun thème sombre n'est actif (le super admin
/// peut l'avoir désactivé) : mieux vaut pas de bouton qu'un bouton sans effet.
class ThemeModeToggle extends StatefulWidget {
  /// Barre dépliée (libellé visible) ou repliée (icône seule + tooltip).
  final bool extended;

  const ThemeModeToggle({super.key, required this.extended});

  @override
  State<ThemeModeToggle> createState() => _ThemeModeToggleState();
}

class _ThemeModeToggleState extends State<ThemeModeToggle> {
  bool _busy = false;

  Future<void> _toggle() async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final cible = await ThemeController.instance.pickToggleTarget();
      if (cible == null) {
        _say(messenger, 'Aucun thème disponible pour cette bascule.');
        return;
      }
      final signedIn = AuthService.isLoggedIn;
      try {
        // Applique + retient (appareil, et compte si connecté).
        await AuthService.saveThemePreference(cible);
        _say(messenger, _confirmation(cible, signedIn: signedIn));
      } catch (_) {
        // Le thème est bien appliqué et retenu sur cet appareil ; seule
        // l'écriture sur le compte a échoué. On le dit tel quel plutôt que
        // d'annoncer un « sur tous vos appareils » qui serait faux.
        _say(
          messenger,
          '${cible.label} appliqué sur cet appareil. Le réglage n\'a pas pu '
          'être enregistré sur votre compte : il ne suivra pas sur vos autres '
          'appareils.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Le message de confirmation. Il nomme l'effet réel (« votre thème par
  /// défaut ») et la portée (cet appareil / tous vos appareils), et rappelle où
  /// revenir dessus.
  String _confirmation(ThemeRef theme, {required bool signedIn}) {
    final sombre = theme.palette.isDark;
    final quoi = sombre ? 'Thème sombre activé' : 'Thème clair rétabli';
    final portee = signedIn
        ? 'C\'est désormais votre thème par défaut : vous le retrouverez à '
              'chaque connexion, sur tous vos appareils.'
        : 'C\'est désormais votre thème par défaut sur cet appareil, et il '
              'sera conservé lorsque vous vous connecterez.';
    return '$quoi. $portee Vous pouvez en changer dans « Mon profil › '
        'Apparence ».';
  }

  void _say(ScaffoldMessengerState? messenger, String message) {
    if (messenger == null || !mounted) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 6),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppPalette>(
      valueListenable: ThemeController.instance,
      builder: (context, palette, _) {
        // Pas de thème sombre proposé → pas de bouton (plutôt qu'un bouton
        // inerte). `darkTheme` est vide tant que les thèmes ne sont pas
        // chargés : le bouton apparaît dès que c'est fait.
        if (ThemeController.instance.darkTheme == null) {
          return const SizedBox.shrink();
        }
        final dark = palette.isDark;
        // L'icône annonce la DESTINATION (soleil quand on peut revenir au
        // clair) : c'est la convention la plus répandue, et elle se comprend
        // sans libellé quand la barre est repliée.
        final icon = dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined;
        final label = dark ? 'Thème clair' : 'Thème sombre';

        final btn = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadius.borderMd,
            child: InkWell(
              onTap: _busy ? null : _toggle,
              borderRadius: AppRadius.borderMd,
              hoverColor: AppColors.surfaceContainerLow,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: widget.extended
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 20, color: AppColors.onSurfaceVariant),
                          const SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Icon(
                          icon,
                          size: 20,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
              ),
            ),
          ),
        );

        return Semantics(
          button: true,
          label: dark
              ? 'Revenir au thème clair'
              : 'Activer le thème sombre',
          child: Tooltip(
            message: dark
                ? 'Revenir au thème clair'
                : 'Passer au thème sombre (devient votre thème par défaut)',
            child: btn,
          ),
        );
      },
    );
  }
}
