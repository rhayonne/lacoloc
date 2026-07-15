/// Conditions **obligatoires** à renseigner avant de pouvoir signer/finaliser un
/// EDL (le bail et l'EDL sont signés ensemble). Sert à trois choses :
/// 1. le **badge** par onglet (nombre de champs obligatoires manquants) ;
/// 2. l'**indicateur** « obligatoire » sur chaque champ ;
/// 3. le **verrou** de finalisation (impossible tant que `missing` n'est pas vide).
///
/// Ne compte que des **champs de configuration** (fenêtre d'avenant, choix
/// garant, garants, mode de caution) — la signature elle-même est l'acte final,
/// pas un « champ à remplir avant de signer ».
library;

/// Section (≈ onglet) où vit une condition obligatoire.
enum EdlReqSection { bail, garant, caution }

/// Une condition obligatoire manquante (libellé + section).
class EdlRequirement {
  final String label;
  final EdlReqSection section;
  const EdlRequirement(this.label, this.section);
}

class EdlReadiness {
  const EdlReadiness._();

  /// Liste des conditions obligatoires **manquantes**. Vide = prêt à signer.
  static List<EdlRequirement> missing({
    required int? avenantWindowDays,
    required bool? bailAvecGarant,
    required int garantsCount,
    required String? cautionMode,
  }) {
    final out = <EdlRequirement>[];
    // Fenêtre d'avenant : rien n'est présélectionné → doit être choisie.
    if (avenantWindowDays == null) {
      out.add(const EdlRequirement("Fenêtre d'avenant", EdlReqSection.bail));
    }
    // Choix avec/sans garant, puis au moins un garant si « avec ».
    if (bailAvecGarant == null) {
      out.add(const EdlRequirement(
          'Bail avec ou sans garant', EdlReqSection.bail));
    } else if (bailAvecGarant && garantsCount < 1) {
      out.add(const EdlRequirement('Au moins un garant', EdlReqSection.garant));
    }
    // Mode de règlement de la caution.
    if (cautionMode == null || cautionMode.isEmpty) {
      out.add(const EdlRequirement(
          'Mode de règlement de la caution', EdlReqSection.caution));
    }
    return out;
  }

  /// Nombre de conditions manquantes pour une [section] donnée.
  static int countForSection(List<EdlRequirement> missing, EdlReqSection s) =>
      missing.where((r) => r.section == s).length;
}

/// Modes de règlement de la caution (dépôt de garantie).
enum CautionMode {
  cheque('cheque', 'Chèque'),
  virement('virement', 'Virement (SEPA)'),
  especes('especes', 'Espèces'),
  weroPaypal('wero_paypal', 'Wero / PayPal');

  const CautionMode(this.raw, this.label);
  final String raw;
  final String label;

  static CautionMode? fromRaw(String? raw) {
    for (final m in CautionMode.values) {
      if (m.raw == raw) return m;
    }
    return null;
  }
}
