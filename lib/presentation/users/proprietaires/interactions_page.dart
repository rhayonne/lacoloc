import 'package:flutter/material.dart';
import 'package:habitafrance/presentation/messagerie/messagerie_model.dart';
import 'package:habitafrance/presentation/messagerie/messagerie_view.dart';

/// Page « Messages » du propriétaire — les prises de contact des locataires,
/// façon messagerie.
///
/// Tout l'écran vit dans [MessagerieView], **partagé avec le locataire**
/// (« Mes discussions ») : seule la configuration de rôle change. Corriger ou
/// enrichir la messagerie se fait donc à un seul endroit, jamais en double.
class InteractionsPage extends StatelessWidget {
  /// Ouvre directement un fil (ex. arrivée depuis une notification).
  final int? initialDemandeId;

  /// Ouvre l'annonce dans le cadre de l'écran hôte plutôt qu'en nouvelle route.
  final void Function(int chambreId)? onVoirAnnonce;

  const InteractionsPage({
    super.key,
    this.initialDemandeId,
    this.onVoirAnnonce,
  });

  @override
  Widget build(BuildContext context) {
    return MessagerieView(
      role: MessagerieRole.proprietaire,
      title: 'Messages',
      initialDemandeId: initialDemandeId,
      onVoirAnnonce: onVoirAnnonce,
    );
  }
}
