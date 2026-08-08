import 'package:habitafrance/data/models/vetuste.dart';

/// Moteur de calcul de la vétusté (pur, sans dépendance UI ni réseau).
///
/// Modèle français (décret n° 2016-382) : abattement annuel après une
/// franchise, plafonné de sorte qu'un pourcentage résiduel minimum subsiste.
class VetusteCalc {
  VetusteCalc._();

  /// Rangs d'état d'usure pour comparer entrée → sortie (N < B < U < M).
  static const Map<String, int> etatRank = {
    'N': 0, // neuf
    'B': 1, // bon état
    'U': 2, // état d'usage
    'M': 3, // mauvais état
  };

  /// Vrai si [sortie] est un état strictement plus dégradé que [entree].
  static bool estDegrade(String? entree, String? sortie) {
    final e = etatRank[entree] ?? 0;
    final s = etatRank[sortie] ?? 0;
    return s > e;
  }

  /// Âge en années (peut être fractionnaire) entre [dateAcquisition] et [ref].
  static double ageAnnees(DateTime? dateAcquisition, {DateTime? ref}) {
    if (dateAcquisition == null) return 0;
    final to = ref ?? DateTime.now();
    final days = to.difference(dateAcquisition).inDays;
    return days <= 0 ? 0 : days / 365.25;
  }

  /// Pourcentage d'abattement (0–100) pour un âge donné selon le barème.
  /// `clamp((âge − franchise) × coef_annuel, 0, 100 − résiduel_min)`.
  static double abattementPct(VetusteBaremeModel? bareme, double ageAnnees) {
    if (bareme == null) return 0;
    final effectif = ageAnnees - bareme.franchiseAnnees;
    if (effectif <= 0) return 0;
    final brut = effectif * bareme.coefficientAnnuel;
    final plafond = (100 - bareme.residuelMinPct).clamp(0, 100).toDouble();
    return brut.clamp(0, plafond).toDouble();
  }

  /// Valeur résiduelle = valeur d'achat × (1 − abattement/100).
  static double valeurResiduelle(double valeurAchat, double abattementPct) {
    final v = valeurAchat * (1 - abattementPct / 100);
    return v < 0 ? 0 : v;
  }
}
