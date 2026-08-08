import 'package:flutter/material.dart';
import 'package:habitafrance/theme/app_radius.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Catégorie d'annonce affichée par [ListingTypeBadge] : location (immeuble
/// entier, un seul bail) ou colocation (chambre individuelle, bail individuel).
enum ListingType { location, colocation }

/// Badge superposé à la photo (grille mixte de la home) indiquant si la carte
/// est une « Location » (immeuble entier) ou une « Colocation » (chambre) —
/// même style visuel que le badge de disponibilité, pour cohabiter avec lui.
class ListingTypeBadge extends StatelessWidget {
  final ListingType type;

  const ListingTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final isLocation = type == ListingType.location;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: AppRadius.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLocation ? Icons.apartment_outlined : Icons.groups_outlined,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            isLocation ? 'Location' : 'Colocation',
            style: AppTypography.labelSm.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }
}
