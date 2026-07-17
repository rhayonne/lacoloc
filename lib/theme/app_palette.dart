import 'package:flutter/material.dart';

/// ═════════════════════════════════════════════════════════════════════════════
/// PALETTES DE L'APPLICATION
/// ═════════════════════════════════════════════════════════════════════════════
///
/// ## Le concept
///
/// Super Loc est un **outil d'enregistrement de l'état des lieux** : son monde,
/// ce sont les états des lieux, les plans de chambre (4 murs + sol + plafond),
/// les tantièmes, les relevés de compteurs. Le langage visuel découle de là —
/// **le relevé annoté** :
///
/// - Les **neutres chauds** (plâtre) sont le *relevé* : le support, le papier,
///   le fond neutre sur lequel on consigne.
/// - L'**ocre** (orange brûlé) est la *couche d'annotation* : ce que l'humain a
///   marqué, décidé, validé. C'est la couleur du trait du géomètre sur le plan.
/// - Le **pétrole** (bleu-vert froid) est le contrepoids *informatif* : l'état
///   d'une chose, pas une action.
/// - La **mousse** (vert) valide ; le **lie-de-vin** alerte.
///
/// ## Pourquoi ces valeurs précises
///
/// - L'ocre est à ~14° de teinte (orange-rouge), **pas** terracotta (~28°, trop
///   proche de la brique/argile) ni orange « startup » (~25° très clair).
/// - Le lie-de-vin d'erreur est à ~342°, volontairement **éloigné de l'ocre** :
///   dans une app à primaire orange, un rouge d'erreur trop proche de la
///   primaire devient indistinguable (« ce bouton est-il dangereux ou
///   principal ? »). 32° d'écart les sépare clairement.
/// - Le fond n'est **pas** un crème (#F4F1EA, jaune-chaud) mais un blanc de
///   plâtre (rose-chaud, très faible chroma) : il appartient à la famille de
///   l'ocre sans virer au beige.
/// - Tous les couples texte/fond sont vérifiés ≥ 4.5:1 (AA). Les valeurs
///   « vives » (ex. [primaryContainer]) sont réservées aux **grands éléments**
///   (≥ 18px, pastilles, icônes), jamais au corps de texte.
///
/// ## Comment ajouter/modifier un thème
///
/// 1. Créez une nouvelle `AppPalette(...)` ci-dessous (tous les champs sont
///    obligatoires : on ne veut pas de thème à moitié défini).
/// 2. Ajoutez une valeur à [AppPaletteId] et branchez-la dans [AppPalettes.of].
/// 3. C'est tout : `AppColors` lit la palette courante, donc **toute
///    l'application** suit sans qu'aucun écran ne soit modifié.
///
/// Ne référencez jamais une palette directement depuis un écran : passez
/// toujours par `AppColors.<token>` (voir `app_colors.dart`).

/// Identifiant d'un thème — c'est la valeur persistée en base
/// (`Users_Client.theme_preference`), d'où le [code] stable et explicite.
enum AppPaletteId {
  /// Ocre — papier chaud + orange brûlé.
  ocre('ocre', 'Ocre', 'Papier chaud et orange brûlé.'),

  /// Ardoise — bleu pétrole sur fond froid. **Thème par défaut** (voir
  /// `ThemeController.defaultPalette`) : c'est ce que voit un visiteur.
  ardoise('ardoise', 'Ardoise', 'Bleu pétrole et fond froid. Le thème par défaut.'),

  /// Encre — quasi monochrome : gris chauds, l'ocre comme seule couleur.
  /// Pensé pour les longues journées dans le tableau de bord.
  encre('encre', 'Encre', 'Gris chauds, une seule couleur d\'accent. Sobre.');

  const AppPaletteId(this.code, this.label, this.description);

  /// Valeur stockée en base. **Ne pas renommer** (romprait les préférences
  /// déjà enregistrées).
  final String code;

  /// Nom affiché dans le sélecteur de thème.
  final String label;

  /// Une phrase décrivant le thème, affichée sous le nom.
  final String description;

  /// Code inconnu/absent → thème par défaut (`ThemeController.defaultPalette`,
  /// volontairement non importé ici pour éviter une dépendance circulaire).
  static AppPaletteId fromCode(String? code) => AppPaletteId.values.firstWhere(
    (p) => p.code == code,
    orElse: () => AppPaletteId.ardoise,
  );
}

/// Jeu complet de couleurs d'un thème. Immuable : un thème est une valeur, pas
/// un état. Tous les champs sont requis pour qu'un nouveau thème ne puisse pas
/// oublier un token (et hériter d'une couleur d'un autre thème par accident).
@immutable
class AppPalette {
  // ── Surfaces / neutres ─────────────────────────────────────────────────────
  final Color surface;
  final Color surfaceDim;
  final Color surfaceBright;
  final Color surfaceContainerLowest;
  final Color surfaceContainerLow;
  final Color surfaceContainer;
  final Color surfaceContainerHigh;
  final Color surfaceContainerHighest;
  final Color onSurface;
  final Color onSurfaceVariant;
  final Color inverseSurface;
  final Color inverseOnSurface;
  final Color outline;
  final Color outlineVariant;
  final Color surfaceTint;
  final Color surfaceVariant;

  // ── Primary — l'action, la décision, l'annotation ──────────────────────────
  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color inversePrimary;
  final Color primaryFixed;
  final Color primaryFixedDim;
  final Color onPrimaryFixed;
  final Color onPrimaryFixedVariant;

  // ── Secondary — l'état, l'information (contrepoids froid) ──────────────────
  final Color secondary;
  final Color onSecondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color secondaryFixed;
  final Color secondaryFixedDim;
  final Color onSecondaryFixed;
  final Color onSecondaryFixedVariant;

  // ── Tertiary — validé, signé, payé (sert aussi de « success ») ─────────────
  final Color tertiary;
  final Color onTertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color tertiaryFixed;
  final Color tertiaryFixedDim;
  final Color onTertiaryFixed;
  final Color onTertiaryFixedVariant;

  // ── Error — danger, suppression, litige ────────────────────────────────────
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;

  /// Teinte des ombres — chaude ou froide selon le thème, jamais du noir pur.
  final Color shadowTint;

  const AppPalette({
    required this.surface,
    required this.surfaceDim,
    required this.surfaceBright,
    required this.surfaceContainerLowest,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.inverseSurface,
    required this.inverseOnSurface,
    required this.outline,
    required this.outlineVariant,
    required this.surfaceTint,
    required this.surfaceVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.inversePrimary,
    required this.primaryFixed,
    required this.primaryFixedDim,
    required this.onPrimaryFixed,
    required this.onPrimaryFixedVariant,
    required this.secondary,
    required this.onSecondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.secondaryFixed,
    required this.secondaryFixedDim,
    required this.onSecondaryFixed,
    required this.onSecondaryFixedVariant,
    required this.tertiary,
    required this.onTertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.tertiaryFixed,
    required this.tertiaryFixedDim,
    required this.onTertiaryFixed,
    required this.onTertiaryFixedVariant,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.shadowTint,
  });
}

/// Les thèmes disponibles. Tous **clairs** : l'app est un outil de travail
/// consulté en journée, et un thème sombre demanderait de revalider chaque
/// couple de contraste (à faire séparément si le besoin apparaît).
class AppPalettes {
  AppPalettes._();

  /// Résout un identifiant en palette concrète.
  static AppPalette of(AppPaletteId id) => switch (id) {
    AppPaletteId.ocre => ocre,
    AppPaletteId.ardoise => ardoise,
    AppPaletteId.encre => encre,
  };

  /// Palette **intégrée** portant ce code, ou `null` si le code correspond à un
  /// thème personnalisé (créé par le super admin) : celui-là est dérivé de ses
  /// 3 couleurs par `PaletteBuilder`, pas réglé à la main ici.
  static AppPalette? byCode(String code) => switch (code) {
    'ocre' => ocre,
    'ardoise' => ardoise,
    'encre' => encre,
    _ => null,
  };

  // ═══════════════════════════════════════════════════════════════════════════
  // OCRE — identité par défaut
  // Papier de plâtre (rose-chaud, très faible chroma) + ocre brûlé (~14°)
  // + pétrole (~192°) + mousse (~157°) + lie-de-vin (~342°).
  // ═══════════════════════════════════════════════════════════════════════════
  static const AppPalette ocre = AppPalette(
    // Plâtre — chaud sans virer au crème.
    surface: Color(0xFFFAF7F5),
    surfaceDim: Color(0xFFE4DDD8),
    surfaceBright: Color(0xFFFDFBFA),
    // Les cartes sont blanches sur fond plâtre : elles « lèvent » sans ombre.
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF5F1EE),
    surfaceContainer: Color(0xFFEFEAE6),
    surfaceContainerHigh: Color(0xFFE9E3DE),
    surfaceContainerHighest: Color(0xFFE3DCD6),
    onSurface: Color(0xFF1F1815), // encre chaude, pas un noir froid
    onSurfaceVariant: Color(0xFF574A43), // 7.4:1 sur `surface`
    inverseSurface: Color(0xFF352D28),
    inverseOnSurface: Color(0xFFF8F0EC),
    outline: Color(0xFF8A7A70),
    outlineVariant: Color(0xFFDDD3CC),
    surfaceTint: Color(0xFFC43E15),
    surfaceVariant: Color(0xFFE3DCD6),

    // Ocre brûlé — 5.2:1 sur blanc (AA pour du texte blanc sur bouton plein).
    primary: Color(0xFFC43E15),
    onPrimary: Color(0xFFFFFFFF),
    // Vif : 3.4:1 — réservé aux grands éléments (pastilles, icônes), pas au corps.
    primaryContainer: Color(0xFFEC5B30),
    onPrimaryContainer: Color(0xFF4A1405),
    inversePrimary: Color(0xFFFFB59C),
    primaryFixed: Color(0xFFFFE3D8), // fond des pastilles / item de menu actif
    primaryFixedDim: Color(0xFFFFB59C),
    onPrimaryFixed: Color(0xFF3A0F03),
    onPrimaryFixedVariant: Color(0xFF9A2F0F), // 6.2:1 sur primaryFixed
    // Pétrole — l'information (contrepoids froid de l'ocre).
    secondary: Color(0xFF1C5A66),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFF4E97A6),
    onSecondaryContainer: Color(0xFF063039),
    secondaryFixed: Color(0xFFC7E9F0),
    secondaryFixedDim: Color(0xFF8FCEDA),
    onSecondaryFixed: Color(0xFF051E24),
    onSecondaryFixedVariant: Color(0xFF14444E),

    // Mousse — validé / signé / payé.
    tertiary: Color(0xFF2E6B4F),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF57A37C),
    onTertiaryContainer: Color(0xFF0C3423),
    tertiaryFixed: Color(0xFFBFEBD3), // fond du bouton « Enregistrer »
    tertiaryFixedDim: Color(0xFF8ED4AF),
    onTertiaryFixed: Color(0xFF042315),
    onTertiaryFixedVariant: Color(0xFF205140),

    // Lie-de-vin — à 342°, nettement séparé de l'ocre (14°) pour qu'un bouton
    // « Supprimer » ne puisse jamais être confondu avec un bouton principal.
    error: Color(0xFFB00034),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFD9E0),
    onErrorContainer: Color(0xFF820025),

    shadowTint: Color(0xFF3A2A20), // ombre chaude
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // ARDOISE — l'identité historique de l'app, conservée à l'identique.
  // Bleu pétrole sur fond bleuté froid.
  // ═══════════════════════════════════════════════════════════════════════════
  static const AppPalette ardoise = AppPalette(
    surface: Color(0xFFF6FAFD),
    surfaceDim: Color(0xFFD6DADE),
    surfaceBright: Color(0xFFF6FAFD),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF0F4F8),
    surfaceContainer: Color(0xFFEAEEF2),
    surfaceContainerHigh: Color(0xFFE5E9EC),
    surfaceContainerHighest: Color(0xFFDFE3E6),
    onSurface: Color(0xFF181C1F),
    onSurfaceVariant: Color(0xFF3E484E),
    inverseSurface: Color(0xFF2C3134),
    inverseOnSurface: Color(0xFFEDF1F5),
    outline: Color(0xFF6E797F),
    outlineVariant: Color(0xFFBEC8CF),
    surfaceTint: Color(0xFF006685),
    surfaceVariant: Color(0xFFDFE3E6),

    primary: Color(0xFF006685),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF31A2CC),
    onPrimaryContainer: Color(0xFF003445),
    inversePrimary: Color(0xFF6DD2FE),
    primaryFixed: Color(0xFFBFE9FF),
    primaryFixedDim: Color(0xFF6DD2FE),
    onPrimaryFixed: Color(0xFF001F2A),
    onPrimaryFixedVariant: Color(0xFF004D65),

    secondary: Color(0xFF795900),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFEC330),
    onSecondaryContainer: Color(0xFF6F5100),
    secondaryFixed: Color(0xFFFFDFA0),
    secondaryFixedDim: Color(0xFFF8BD2A),
    onSecondaryFixed: Color(0xFF261A00),
    onSecondaryFixedVariant: Color(0xFF5C4300),

    tertiary: Color(0xFF3C6A00),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF70A636),
    onTertiaryContainer: Color(0xFF1C3600),
    tertiaryFixed: Color(0xFFB8F47A),
    tertiaryFixedDim: Color(0xFF9DD761),
    onTertiaryFixed: Color(0xFF0E2000),
    onTertiaryFixedVariant: Color(0xFF2C5000),

    error: Color(0xFFBA1A1A),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF93000A),

    shadowTint: Color(0xFF1E293B),
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // ENCRE — quasi monochrome. Les gris chauds portent toute l'interface ;
  // l'ocre est la SEULE couleur vive, donc chaque tache d'orange veut dire
  // « c'est ici que ça se passe ». Pour les longues sessions dans le tableau
  // de bord, où un dégradé de couleurs fatigue plus qu'il n'aide.
  // ═══════════════════════════════════════════════════════════════════════════
  static const AppPalette encre = AppPalette(
    surface: Color(0xFFF7F6F4),
    surfaceDim: Color(0xFFE0DDD8),
    surfaceBright: Color(0xFFFCFBFA),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF1EFEC),
    surfaceContainer: Color(0xFFEAE7E3),
    surfaceContainerHigh: Color(0xFFE3E0DB),
    surfaceContainerHighest: Color(0xFFDCD8D3),
    onSurface: Color(0xFF1A1815),
    onSurfaceVariant: Color(0xFF4E4A44),
    inverseSurface: Color(0xFF302D29),
    inverseOnSurface: Color(0xFFF4F2EF),
    outline: Color(0xFF7C776F),
    outlineVariant: Color(0xFFD6D1CA),
    surfaceTint: Color(0xFFC43E15),
    surfaceVariant: Color(0xFFDCD8D3),

    // La seule couleur vive du thème.
    primary: Color(0xFFC43E15),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFEC5B30),
    onPrimaryContainer: Color(0xFF4A1405),
    inversePrimary: Color(0xFFFFB59C),
    primaryFixed: Color(0xFFFFE3D8),
    primaryFixedDim: Color(0xFFFFB59C),
    onPrimaryFixed: Color(0xFF3A0F03),
    onPrimaryFixedVariant: Color(0xFF9A2F0F),

    // « Secondary » devient un gris : un état n'a pas besoin de crier.
    secondary: Color(0xFF4E4A44),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFF8A857C),
    onSecondaryContainer: Color(0xFF2A2721),
    secondaryFixed: Color(0xFFE3E0DB),
    secondaryFixedDim: Color(0xFFC5C0B8),
    onSecondaryFixed: Color(0xFF1A1815),
    onSecondaryFixedVariant: Color(0xFF3D3933),

    // Le vert reste, mais très désaturé : il valide sans se disputer avec l'ocre.
    tertiary: Color(0xFF3E5F49),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFF6E9077),
    onTertiaryContainer: Color(0xFF19301F),
    tertiaryFixed: Color(0xFFD3E4D7),
    tertiaryFixedDim: Color(0xFFA8C4AF),
    onTertiaryFixed: Color(0xFF0F1F13),
    onTertiaryFixedVariant: Color(0xFF2F4A38),

    error: Color(0xFF8F2438),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF4DCE0),
    onErrorContainer: Color(0xFF6B1A29),

    shadowTint: Color(0xFF2A2721),
  );
}
