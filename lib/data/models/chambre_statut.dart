import 'package:lacoloc_front/data/models/etat_de_lieux.dart';

/// Phases du statut d'une chambre, dérivées de l'EDL d'**entrée** privatif et
/// de l'occupation. Reflète l'avancement du processus de location plutôt qu'un
/// simple « loué / libre ».
enum ChambreStatut {
  /// Aucun EDL d'entrée : la chambre est disponible.
  libre,

  /// EDL d'entrée en cours de rédaction (pas encore finalisé).
  edlEntreeEnCours,

  /// EDL d'entrée finalisé, en attente de la signature du locataire.
  attenteSignature,

  /// Locataire a signé l'EDL d'entrée → bail signé / chambre louée.
  loue;

  String get label => switch (this) {
        ChambreStatut.libre => 'Libre',
        ChambreStatut.edlEntreeEnCours => "EDL d'entrée en cours",
        ChambreStatut.attenteSignature => 'En attente de signature',
        ChambreStatut.loue => 'Bail signé · Louée',
      };

  /// Dérive le statut depuis l'EDL d'entrée privatif [entree] (peut être null)
  /// et le drapeau d'occupation [estLoue] (repli si aucun EDL).
  static ChambreStatut from({EtatDesLieuxModel? entree, bool estLoue = false}) {
    if (entree == null) return estLoue ? ChambreStatut.loue : ChambreStatut.libre;
    if (entree.situation != SituationEdl.finalise) {
      return ChambreStatut.edlEntreeEnCours;
    }
    return entree.locataireAccepte
        ? ChambreStatut.loue
        : ChambreStatut.attenteSignature;
  }
}
