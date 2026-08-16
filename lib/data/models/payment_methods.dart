/// Coordonnées de paiement d'un utilisateur (table `User_Payment_Methods`).
///
/// **Table à part, et non des colonnes sur `Users_Client`** : les politiques
/// SELECT de `Users_Client` ouvrent la ligne entière au bailleur lié (contrat
/// ou simple invitation), au locataire lié, à l'admin de groupe et au super
/// admin. Un IBAN posé là serait lisible par tous ceux-là. Ici la règle est
/// unique et non contournable : **seul le titulaire lit et écrit**.
class PaymentMethods {
  final String userId;

  /// Coordonnées bancaires (virement — la voie principale du loyer).
  final String? titulaireCompte;
  final String? iban;
  final String? bic;

  /// Paiements instantanés.
  final String? telephoneWero;
  final bool weroActif;
  final String? emailPaypal;
  final bool paypalActif;

  const PaymentMethods({
    required this.userId,
    this.titulaireCompte,
    this.iban,
    this.bic,
    this.telephoneWero,
    this.weroActif = false,
    this.emailPaypal,
    this.paypalActif = false,
  });

  /// Fiche vierge — un utilisateur qui n'a encore rien renseigné n'a pas de
  /// ligne en base, et l'écran doit quand même s'afficher.
  factory PaymentMethods.empty(String userId) => PaymentMethods(userId: userId);

  factory PaymentMethods.fromMap(Map<String, dynamic> map) => PaymentMethods(
    userId: map['user_id'] as String,
    titulaireCompte: map['titulaire_compte'] as String?,
    iban: map['iban'] as String?,
    bic: map['bic'] as String?,
    telephoneWero: map['telephone_wero'] as String?,
    weroActif: map['wero_actif'] as bool? ?? false,
    emailPaypal: map['email_paypal'] as String?,
    paypalActif: map['paypal_actif'] as bool? ?? false,
  );

  /// Ligne à écrire (upsert sur `user_id`).
  ///
  /// Les chaînes vides sont normalisées en `null` : « champ effacé » et « champ
  /// jamais rempli » sont la même chose, et une chaîne vide en base ferait
  /// croire à une coordonnée renseignée.
  Map<String, dynamic> toUpsert() => {
    'user_id': userId,
    'titulaire_compte': _vide(titulaireCompte),
    'iban': _vide(iban) == null ? null : normaliserIban(iban!),
    'bic': _vide(bic)?.toUpperCase(),
    'telephone_wero': _vide(telephoneWero),
    'wero_actif': weroActif,
    'email_paypal': _vide(emailPaypal),
    'paypal_actif': paypalActif,
  };

  static String? _vide(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  /// Vrai si au moins une coordonnée est renseignée — sert à afficher
  /// « aucun moyen de paiement » plutôt qu'une fiche vide trompeuse.
  bool get estVide =>
      _vide(titulaireCompte) == null &&
      _vide(iban) == null &&
      _vide(bic) == null &&
      _vide(telephoneWero) == null &&
      _vide(emailPaypal) == null;

  PaymentMethods copyWith({
    String? titulaireCompte,
    String? iban,
    String? bic,
    String? telephoneWero,
    bool? weroActif,
    String? emailPaypal,
    bool? paypalActif,
  }) => PaymentMethods(
    userId: userId,
    titulaireCompte: titulaireCompte ?? this.titulaireCompte,
    iban: iban ?? this.iban,
    bic: bic ?? this.bic,
    telephoneWero: telephoneWero ?? this.telephoneWero,
    weroActif: weroActif ?? this.weroActif,
    emailPaypal: emailPaypal ?? this.emailPaypal,
    paypalActif: paypalActif ?? this.paypalActif,
  );

  // ───────────────────────────────────────────────────────────────────────────
  // IBAN
  // ───────────────────────────────────────────────────────────────────────────

  /// Retire espaces et ponctuation, passe en majuscules.
  /// « FR76 3000 1007 94 » et « fr7630001007 94 » donnent la même chaîne.
  static String normaliserIban(String saisie) =>
      saisie.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();

  /// Contrôle **mod 97** (norme ISO 13616) : détecte une faute de frappe avant
  /// qu'un virement parte au mauvais endroit. Ce n'est pas une garantie que le
  /// compte existe — seulement que le numéro est cohérent.
  static bool ibanValide(String saisie) {
    final iban = normaliserIban(saisie);
    if (iban.length < 15 || iban.length > 34) return false;
    if (!RegExp(r'^[A-Z]{2}[0-9]{2}[A-Z0-9]+$').hasMatch(iban)) return false;

    // Les 4 premiers caractères passent à la fin, puis chaque lettre devient
    // sa position dans l'alphabet + 9 (A=10 … Z=35).
    final reordonne = iban.substring(4) + iban.substring(0, 4);
    final buffer = StringBuffer();
    for (final c in reordonne.codeUnits) {
      if (c >= 65 && c <= 90) {
        buffer.write(c - 55);
      } else {
        buffer.writeCharCode(c);
      }
    }

    // Le nombre dépasse largement un int : on prend le modulo par tranches.
    var reste = 0;
    for (final chiffre in buffer.toString().codeUnits) {
      reste = (reste * 10 + (chiffre - 48)) % 97;
    }
    return reste == 1;
  }

  /// Affichage groupé par 4, comme sur un RIB : « FR76 3000 1007 94… ».
  static String formaterIban(String saisie) {
    final iban = normaliserIban(saisie);
    final groupes = <String>[];
    for (var i = 0; i < iban.length; i += 4) {
      groupes.add(iban.substring(i, (i + 4).clamp(0, iban.length)));
    }
    return groupes.join(' ');
  }
}
