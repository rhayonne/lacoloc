import 'package:lacoloc_front/data/models/immeuble_lot.dart';
import 'package:lacoloc_front/data/models/inventaire.dart';

/// Modèles « brouillon » (draft) tenus en mémoire pendant la création d'un
/// immeuble — l'équivalent d'un état Formik pour les *collections* que
/// flutter_form_builder ne gère pas (les champs scalaires restent dans le
/// FormBuilder). Rien n'est écrit en base avant le clic « Enregistrer ».

/// Une pièce commune choisie par l'utilisateur, avec sa quantité.
/// Une quantité N > 1 produira N pièces séparées (« WC 1 », « WC 2 »…).
class PieceDraft {
  final String nom;
  int quantite;

  PieceDraft({required this.nom, this.quantite = 1});
}

/// Un article d'inventaire en brouillon (utilisé pour l'électroménager au
/// niveau de l'immeuble, et réutilisable pour l'inventaire des pièces).
class ArticleDraft {
  /// Référence Meubles_Reference choisie, sinon [nomCustom] est un texte libre.
  final MeubleReferenceModel? ref;
  final String? nomCustom;
  final int quantite;
  final double? valeur;
  final String? description;
  final List<String> photos;

  // Vétusté
  final double? valeurAchat;
  final DateTime? dateAcquisition;

  const ArticleDraft({
    this.ref,
    this.nomCustom,
    this.quantite = 1,
    this.valeur,
    this.description,
    this.photos = const [],
    this.valeurAchat,
    this.dateAcquisition,
  });

  /// Catégorie de vétusté = celle du meuble de référence (les électroménagers
  /// sont filtrés sur la catégorie « Électroménager »).
  String? get categorieVetuste => ref?.categorie;

  /// Nom affichable : nom libre sinon le nom de la référence.
  String get displayNom => nomCustom ?? ref?.nom ?? '—';
}

/// Brouillon global du formulaire « Nouvel immeuble » : agrège les collections.
class ImmeubleDraft {
  /// Pièces communes sélectionnées (case cochée + quantité).
  final List<PieceDraft> pieces = [];

  /// Articles d'électroménager au niveau de l'immeuble.
  final List<ArticleDraft> electromenager = [];

  /// Lots de copropriété **sélectionnés** (déjà existants en base — créés via
  /// le catalogue « Lots » ou à la volée — mais pas encore rattachés : le
  /// rattachement (`immeuble_id`) n'a lieu qu'à l'enregistrement).
  final List<ImmeubleLotModel> lots = [];

  /// Vrai une fois que l'utilisateur a cliqué « Ajouter les pièces communes et
  /// inventaire » : la sélection a été matérialisée (récapitulatif affiché).
  bool inventaireGenere = false;
}
