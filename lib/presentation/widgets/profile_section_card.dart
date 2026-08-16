import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';

/// Conteneur d'une **section** de l'écran « Mon Profil ».
///
/// L'écran est découpé en sections, une par sujet — mes informations, ma fiche
/// de profil, mes moyens de paiement, ma signature, l'apparence. Chaque section
/// vit dans sa propre carte : on voit tout de suite où commence et où finit un
/// sujet, au lieu d'une longue colonne séparée par des traits.
///
/// La carte ne porte **que** le cadre : le titre et le contenu appartiennent à
/// la section elle-même ([PaymentMethodsSection], [ProfileVisibilitySection]…),
/// qui reste utilisable ailleurs sans ce cadre.
///
/// **Les deux profils utilisent ce widget** — propriétaire et locataire. Une
/// section ajoutée d'un côté se pose de l'autre sans retouche visuelle.
class ProfileSectionCard extends StatelessWidget {
  final Widget child;

  const ProfileSectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppRadius.borderMd,
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: child,
    );
  }
}
