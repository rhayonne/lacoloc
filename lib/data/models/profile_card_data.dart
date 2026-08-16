import 'package:habitafrance/data/models/profile_visibility.dart';
import 'package:habitafrance/data/models/users_client.dart';

/// Ce qu'on affiche d'une personne dans une **fiche de profil**
/// (`UserProfileCard`) — indépendamment de l'écran qui la montre : messagerie,
/// fiche d'annonce, aperçu de son propre profil…
///
/// Le filtrage par [ProfileVisibility] est fait **ici**, à la construction :
/// un champ masqué par son propriétaire n'atteint jamais la couche UI, donc
/// aucun écran ne peut l'afficher par inadvertance.
class ProfileCardData {
  /// `auth.users.id` de la personne affichée (null si l'info manque).
  final String? userId;

  /// Toujours affiché : on ne discute pas avec « quelqu'un ».
  final String? fullName;

  /// Sous-titre libre (ex. « Chambre 1 — APT test coloc », « Propriétaire »).
  final String? subtitle;

  final ProfileVisibility visibility;

  final String? _phone;
  final String? _email;
  final int? _age;

  ProfileCardData({
    this.userId,
    this.fullName,
    this.subtitle,
    String? phone,
    String? email,
    int? age,
    this.visibility = ProfileVisibility.defaults,
  })  : _phone = phone,
        _email = email,
        _age = age;

  /// Fiche **déjà filtrée par le serveur** (RPC `demande_counterpart_profiles`).
  ///
  /// Le tri par visibilité a eu lieu en base : ce qui arrive ici est, par
  /// construction, ce que la personne accepte de montrer — un champ masqué vaut
  /// `null` et n'a même pas été transmis. On passe donc une visibilité « tout
  /// ouvert » : il n'y a plus rien à retirer, et `visibleFields` écarte de
  /// toute façon les champs vides.
  factory ProfileCardData.preFiltered({
    String? userId,
    String? fullName,
    String? subtitle,
    String? phone,
    String? email,
    int? age,
  }) =>
      ProfileCardData(
        userId: userId,
        fullName: fullName,
        subtitle: subtitle,
        phone: phone,
        email: email,
        age: age,
        visibility: ProfileVisibility.consentiDefaults,
      );

  /// Recopie la fiche avec un sous-titre (le bien concerné, en général) : la
  /// RPC ne connaît que la personne, pas le contexte d'affichage.
  ProfileCardData withSubtitle(String? value) => ProfileCardData(
        userId: userId,
        fullName: fullName,
        subtitle: value,
        phone: _phone,
        email: _email,
        age: _age,
        visibility: visibility,
      );

  /// Fiche de l'utilisateur courant (aperçu dans « Mon Profil »).
  factory ProfileCardData.fromUsersClient(
    UsersClient? user, {
    String? subtitle,
    ProfileVisibility? visibility,
  }) =>
      ProfileCardData(
        userId: user?.id,
        fullName: user?.fullName,
        subtitle: subtitle ?? user?.typeDisplayLabel,
        phone: user?.phone,
        email: user?.email,
        age: user?.calculatedAge,
        visibility: visibility ?? user?.profileVisibility ??
            ProfileVisibility.defaults,
      );

  bool _shown(ProfileVisibilityField f) => visibility.isVisible(f);

  /// `null` dès que la personne a choisi de ne pas le montrer.
  String? get phone => _shown(ProfileVisibilityField.phone) ? _phone : null;
  String? get email => _shown(ProfileVisibilityField.email) ? _email : null;
  int? get age => _shown(ProfileVisibilityField.age) ? _age : null;

  /// Champs réellement affichables, dans l'ordre de l'enum : masqués **et**
  /// vides exclus (une fiche ne doit pas être une colonne de « — »).
  Map<ProfileVisibilityField, String> get visibleFields {
    final out = <ProfileVisibilityField, String>{};
    final a = age;
    if (a != null) out[ProfileVisibilityField.age] = '$a ans';
    final p = phone;
    if (p != null && p.isNotEmpty) out[ProfileVisibilityField.phone] = p;
    final e = email;
    if (e != null && e.isNotEmpty) out[ProfileVisibilityField.email] = e;
    return out;
  }

  /// Initiales pour l'avatar : « Novo Locataire » → « NL ».
  static String initials(String? nom) {
    final parts =
        (nom ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}
