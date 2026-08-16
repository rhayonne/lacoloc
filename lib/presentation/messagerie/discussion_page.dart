import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/demandes_contact.dart';
import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/conversation_view.dart';
import 'package:habitafrance/theme/app_colors.dart';
import 'package:habitafrance/theme/app_spacing.dart';
import 'package:habitafrance/theme/app_typography.dart';

/// Fil de discussion **en page autonome**, pour les contextes qui n'ont pas de
/// cadre où l'afficher : accueil public, route `/chambre`.
///
/// Dans les espaces locataire/propriétaire, le fil s'ouvre au contraire dans le
/// cadre (cf. `MessagerieView`) — conformément à la règle du projet : une fiche
/// ne remplace pas la navigation latérale. Cette page n'est donc que le repli.
class DiscussionPage extends StatefulWidget {
  final int demandeId;
  const DiscussionPage({super.key, required this.demandeId});

  @override
  State<DiscussionPage> createState() => _DiscussionPageState();
}

/// Ce que la page a besoin de charger : la demande **et** la fiche de son
/// interlocuteur (deux appels, car l'identité de l'autre partie passe par une
/// RPC filtrante et non plus par un embed).
typedef _Fil = ({DemandeContactModel? demande, ProfileCardData? interlocuteur});

class _DiscussionPageState extends State<DiscussionPage> {
  late Future<_Fil> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_Fil> _load() async {
    final demande = await DemandesContactDatasource.byId(widget.demandeId);
    if (demande == null) return (demande: null, interlocuteur: null);
    final profils = await DemandesContactDatasource.counterpartProfiles(
      [widget.demandeId],
      refresh: true,
    );
    return (demande: demande, interlocuteur: profils[widget.demandeId]);
  }

  void _reload() {
    final f = _load();
    setState(() {
      _future = f;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Discussion')),
      body: FutureBuilder<_Fil>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError || snap.data?.demande == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      snap.hasError
                          ? 'Erreur : ${snap.error}'
                          : 'Cette discussion est introuvable.',
                      textAlign: TextAlign.center,
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AppButton.primary(
                      icon: Icons.refresh,
                      label: 'Réessayer',
                      onPressed: _reload,
                    ),
                  ],
                ),
              ),
            );
          }
          return ConversationView(
            demande: snap.data!.demande!,
            interlocuteur: snap.data!.interlocuteur,
            onClose: () => Navigator.of(context).maybePop(),
          );
        },
      ),
    );
  }
}
