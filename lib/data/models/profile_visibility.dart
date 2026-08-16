/// Champ de profil dont l'utilisateur choisit lui-même l'affichage vis-à-vis
/// de l'autre partie (un locataire pour un propriétaire, et inversement).
///
/// Le **nom complet** n'en fait volontairement pas partie : on ne peut pas
/// discuter avec « quelqu'un » — il reste toujours visible.
enum ProfileVisibilityField {
  age,
  phone,
  email;

  /// Clé stockée dans `Users_Client.profile_visibility` (JSONB).
  String get key => switch (this) {
        ProfileVisibilityField.age => 'age',
        ProfileVisibilityField.phone => 'phone',
        ProfileVisibilityField.email => 'email',
      };

  /// Libellé affiché (FR).
  String get label => switch (this) {
        ProfileVisibilityField.age => 'Âge',
        ProfileVisibilityField.phone => 'Téléphone',
        ProfileVisibilityField.email => 'Adresse e-mail',
      };

  /// Ce que l'autre partie voit (ou non) quand l'interrupteur est actif.
  String get hint => switch (this) {
        ProfileVisibilityField.age =>
          'Votre âge, calculé à partir de votre date de naissance.',
        ProfileVisibilityField.phone =>
          'Votre numéro de téléphone, pour être joint directement.',
        ProfileVisibilityField.email =>
          'Votre adresse e-mail, pour être contacté hors de la messagerie.',
      };

  static ProfileVisibilityField? fromKey(String? key) =>
      ProfileVisibilityField.values.where((f) => f.key == key).firstOrNull;
}

/// Préférences d'affichage du profil — quels champs l'utilisateur accepte de
/// montrer à l'autre partie dans la fiche de profil ([UserProfileCard]).
///
/// Persistées dans `Users_Client.profile_visibility` (JSONB). **Tolérant au
/// schéma** : colonne absente, `null`, clé manquante ou valeur non booléenne →
/// on retombe sur le défaut **du rôle** ([defaultsFor]). Une préférence
/// d'affichage ne doit jamais faire échouer un chargement.
///
/// Les défauts sont **asymétriques** à dessein : le locataire consent
/// explicitement à transmettre ses coordonnées en écrivant (pop-up « Entrer en
/// contact »), le bailleur n'a rien consenti du tout — donc rien ne sort de
/// son profil tant qu'il ne l'a pas activé. Voir [consentiDefaults] /
/// [minimalDefaults].
///
/// ⚠️ C'est un **confort d'affichage**, pas une barrière de confidentialité :
/// la RLS (`users_client_select_demande_counterpart`) autorise déjà chaque
/// partie d'une demande à lire la fiche de l'autre. Masquer un champ le retire
/// de l'interface, pas de la base.
class ProfileVisibility {
  final bool age;
  final bool phone;
  final bool email;

  const ProfileVisibility({
    this.age = true,
    this.phone = true,
    this.email = true,
  });

  /// **Tout visible.** Le défaut du *locataire* : au moment d'écrire, le pop-up
  /// « Entrer en contact » lui annonce explicitement que nom, âge, téléphone et
  /// e-mail seront transmis au propriétaire, et il valide en envoyant. Le
  /// consentement est donc éclairé et donné au bon moment.
  static const ProfileVisibility consentiDefaults =
      ProfileVisibility(age: true, phone: true, email: true);

  /// **Rien de partagé.** Le défaut du *bailleur* (propriétaire, admin
  /// d'entreprise…) : personne ne lui a demandé son accord pour diffuser ses
  /// coordonnées à chaque locataire qui le contacte. Rien ne doit sortir par
  /// simple omission — c'est la minimisation des données (RGPD, art. 5.1.c) et
  /// la protection des données **par défaut** (art. 25.2). Il active ce qu'il
  /// veut, en connaissance de cause. La messagerie reste le canal de contact.
  static const ProfileVisibility minimalDefaults =
      ProfileVisibility(age: false, phone: false, email: false);

  /// Le défaut applicable à quelqu'un selon son rôle.
  static ProfileVisibility defaultsFor({required bool isLocataire}) =>
      isLocataire ? consentiDefaults : minimalDefaults;

  /// Repli historique (tout visible) — conservé pour les appels qui ne
  /// connaissent pas le rôle. **Préférez [defaultsFor]** : sans rôle, on
  /// retombe sur le comportement d'avant, donc trop permissif pour un bailleur.
  static const ProfileVisibility defaults = consentiDefaults;

  bool isVisible(ProfileVisibilityField field) => switch (field) {
        ProfileVisibilityField.age => age,
        ProfileVisibilityField.phone => phone,
        ProfileVisibilityField.email => email,
      };

  ProfileVisibility withField(ProfileVisibilityField field, bool value) =>
      switch (field) {
        ProfileVisibilityField.age => ProfileVisibility(
            age: value, phone: phone, email: email),
        ProfileVisibilityField.phone => ProfileVisibility(
            age: age, phone: value, email: email),
        ProfileVisibilityField.email => ProfileVisibility(
            age: age, phone: phone, email: value),
      };

  /// [fallback] = ce qu'on applique aux clés absentes — **le défaut du rôle**
  /// de la personne (cf. [defaultsFor]), pas un défaut universel.
  factory ProfileVisibility.fromJson(
    Map<String, dynamic>? json, {
    ProfileVisibility fallback = defaults,
  }) {
    if (json == null || json.isEmpty) return fallback;
    bool read(ProfileVisibilityField f) {
      final v = json[f.key];
      return v is bool ? v : fallback.isVisible(f);
    }

    return ProfileVisibility(
      age: read(ProfileVisibilityField.age),
      phone: read(ProfileVisibilityField.phone),
      email: read(ProfileVisibilityField.email),
    );
  }

  /// Lit la valeur telle que renvoyée par PostgREST (Map dynamique ou null).
  factory ProfileVisibility.fromRaw(
    Object? raw, {
    ProfileVisibility fallback = defaults,
  }) =>
      raw is Map
          ? ProfileVisibility.fromJson(Map<String, dynamic>.from(raw),
              fallback: fallback)
          : fallback;

  Map<String, dynamic> toJson() => {
        for (final f in ProfileVisibilityField.values) f.key: isVisible(f),
      };

  @override
  bool operator ==(Object other) =>
      other is ProfileVisibility &&
      other.age == age &&
      other.phone == phone &&
      other.email == email;

  @override
  int get hashCode => Object.hash(age, phone, email);

  @override
  String toString() =>
      'ProfileVisibility(age: $age, phone: $phone, email: $email)';
}
