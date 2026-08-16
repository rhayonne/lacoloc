import 'package:supabase_flutter/supabase_flutter.dart';

/// Adresses e-mail d'administration de la plateforme (`Platform_Settings`).
///
/// Table à **ligne unique** : il n'existe qu'une plateforme. Lecture ouverte à
/// tout utilisateur connecté (l'adresse de support est faite pour être
/// affichée) ; **écriture réservée au super admin** par la RLS — ce sont les
/// adresses qui pilotent l'activation des comptes payants, donc l'admin
/// système ne doit pas pouvoir les détourner.
class PlatformSettings {
  /// Où arrivent les demandes de nouveau compte propriétaire.
  final String? emailNouveauxComptes;

  /// Où arrivent les demandes de support des utilisateurs.
  final String? emailSupport;

  const PlatformSettings({this.emailNouveauxComptes, this.emailSupport});

  static const PlatformSettings vide = PlatformSettings();

  factory PlatformSettings.fromMap(Map<String, dynamic> m) => PlatformSettings(
    emailNouveauxComptes: _vide(m['email_nouveaux_comptes'] as String?),
    emailSupport: _vide(m['email_support'] as String?),
  );

  static String? _vide(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  Map<String, dynamic> toUpdate() => {
    'email_nouveaux_comptes': _vide(emailNouveauxComptes),
    'email_support': _vide(emailSupport),
  };

  PlatformSettings copyWith({
    String? emailNouveauxComptes,
    String? emailSupport,
  }) => PlatformSettings(
    emailNouveauxComptes: emailNouveauxComptes ?? this.emailNouveauxComptes,
    emailSupport: emailSupport ?? this.emailSupport,
  );
}

class PlatformSettingsDatasource {
  PlatformSettingsDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Platform_Settings';

  /// Pas de [DataCache] : une ligne, lue et modifiée sur le même écran — un
  /// cache y ferait réapparaître l'ancienne adresse juste après un
  /// enregistrement.
  static Future<PlatformSettings> get() async {
    final row = await _db.from(_table).select().maybeSingle();
    if (row == null) return PlatformSettings.vide;
    return PlatformSettings.fromMap(row);
  }

  /// Écriture réservée au super admin (RLS `platform_settings_write`). Un autre
  /// profil n'obtient pas d'erreur mais **0 ligne modifiée** : on le détecte
  /// pour ne pas afficher un faux « enregistré ».
  static Future<void> save(PlatformSettings input) async {
    final rows = await _db
        .from(_table)
        .update(input.toUpdate())
        .eq('id', true)
        .select();
    if ((rows as List).isEmpty) {
      throw StateError(
        'Seul le super admin peut modifier les adresses d\'administration.',
      );
    }
  }
}
