import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';

/// Qui regarde la messagerie. **Seules** les différences réellement liées au
/// rôle vivent ici (source des données, libellés, droit de gérer une demande) —
/// tout le reste de l'écran est partagé, cf. [MessagerieView].
enum MessagerieRole { proprietaire, locataire }

/// Un onglet-filtre de la barre supérieure : un libellé + les statuts qu'il
/// regroupe. Le propriétaire pilote le statut détaillé d'une demande ; le
/// locataire, lui, n'a besoin que de « on m'a répondu ou pas ».
class MessagerieStatutFilter {
  final String label;
  final Set<StatutDemande> statuts;

  const MessagerieStatutFilter({required this.label, required this.statuts});

  bool matches(DemandeContactModel d) => statuts.contains(d.statut);

  @override
  bool operator ==(Object other) =>
      other is MessagerieStatutFilter &&
      other.label == label &&
      other.statuts.length == statuts.length &&
      other.statuts.containsAll(statuts);

  @override
  int get hashCode => Object.hash(label, statuts.length);
}

/// Tout ce qui change d'un profil à l'autre, en un seul endroit.
class MessagerieRoleConfig {
  final MessagerieRole role;

  const MessagerieRoleConfig(this.role);

  bool get isProprietaire => role == MessagerieRole.proprietaire;

  String get searchHint => isProprietaire
      ? 'Rechercher un locataire ou dans les messages…'
      : 'Rechercher un propriétaire ou dans les messages…';

  String get emptyTitle => isProprietaire
      ? 'Aucun message pour le moment.'
      : 'Aucune discussion pour le moment.';

  String get emptyHint => isProprietaire
      ? 'Les locataires intéressés par vos annonces apparaîtront ici.'
      : 'Depuis une annonce, cliquez sur « Entrer en contact » pour '
          'écrire au propriétaire.';

  /// Seul le propriétaire gère l'état d'une demande (vue / répondue / ignorée).
  bool get canManageStatut => isProprietaire;

  /// Onglets-filtres proposés (hors « Tous », toujours en tête).
  List<MessagerieStatutFilter> get filters => isProprietaire
      ? const [
          MessagerieStatutFilter(
              label: 'Nouveau', statuts: {StatutDemande.nouveau}),
          MessagerieStatutFilter(
              label: 'Non répondu', statuts: {StatutDemande.nonRepondu}),
          MessagerieStatutFilter(
              label: 'Répondu', statuts: {StatutDemande.repondu}),
          MessagerieStatutFilter(
              label: 'Ignoré', statuts: {StatutDemande.ignore}),
        ]
      : const [
          // Côté locataire, « nouveau » et « non répondu » sont la même
          // attente : le propriétaire n'a pas encore écrit.
          MessagerieStatutFilter(label: 'En attente', statuts: {
            StatutDemande.nouveau,
            StatutDemande.nonRepondu,
            StatutDemande.ignore,
          }),
          MessagerieStatutFilter(
              label: 'Répondu', statuts: {StatutDemande.repondu}),
        ];

  /// Libellé d'état affiché sur une ligne / une fiche, du point de vue du rôle.
  String statutLabel(DemandeContactModel d) => isProprietaire
      ? d.statut.label
      : (d.statut == StatutDemande.repondu ? 'Répondu' : 'En attente');
}

/// Filtre la liste : recherche libre (nom de l'interlocuteur **ou** contenu du
/// fil) + onglet de statut. Fonction pure → testable sans Supabase.
///
/// [profils] = fiches renvoyées par `demande_counterpart_profiles` (le serveur
/// a déjà retiré ce que chacun masque). On y cherche le **nom**, jamais les
/// coordonnées : chercher « 0612… » ne doit pas révéler à qui appartient un
/// numéro qu'on ne verrait pas à l'écran.
///
/// La recherche ne dépasse jamais ce que la RLS autorise déjà : elle n'opère
/// que sur les demandes chargées pour l'utilisateur courant et sur le texte de
/// leurs messages ([MessagesDatasource.searchableTextByDemande]).
List<DemandeContactModel> filterDemandes({
  required List<DemandeContactModel> demandes,
  Map<int, ProfileCardData> profils = const {},
  String query = '',
  Map<int, String> searchText = const {},
  MessagerieStatutFilter? statutFilter,
}) {
  final q = query.trim().toLowerCase();
  return demandes.where((d) {
    if (statutFilter != null && !statutFilter.matches(d)) return false;
    if (q.isEmpty) return true;
    final nom = (profils[d.id]?.fullName ?? '').toLowerCase();
    final bien = d.bienLabel.toLowerCase();
    final texte = (searchText[d.id] ?? '').toLowerCase();
    return nom.contains(q) || bien.contains(q) || texte.contains(q);
  }).toList();
}

/// Compteur par onglet, pour les pastilles des chips.
Map<String, int> countByFilter(
  List<DemandeContactModel> demandes,
  List<MessagerieStatutFilter> filters,
) {
  return {
    for (final f in filters) f.label: demandes.where(f.matches).length,
  };
}
