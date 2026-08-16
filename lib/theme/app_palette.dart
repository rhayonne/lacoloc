import 'package:flutter/material.dart';

/// ═════════════════════════════════════════════════════════════════════════════
/// PALETTES DE L'APPLICATION
/// ═════════════════════════════════════════════════════════════════════════════
///
/// ## Le concept
///
/// HabitaFrance est un **outil d'enregistrement de l'état des lieux** : son monde,
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
  encre('encre', 'Encre', 'Gris chauds, une seule couleur d\'accent. Sobre.'),

  /// Sombre — le pendant nocturne d'Ardoise. Voir [AppPalettes.sombre].
  sombre('sombre', 'Sombre', 'Ardoise de nuit. Pour les pièces peu éclairées.');

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

  /// Ce thème est-il **sombre** ? Déduit du fond de page plutôt que déclaré :
  /// un thème dont le papier est noir *est* sombre, qu'on ait pensé ou non à
  /// cocher une case. Un thème personnalisé créé par le super admin à partir
  /// d'un fond foncé bascule donc tout seul, sans champ supplémentaire à
  /// remplir (ni oublier).
  ///
  /// Ce que ça change concrètement : la [Brightness] du `ColorScheme` (voir
  /// `AppColors.scheme`). Material s'en sert pour tout ce qu'il décide seul —
  /// curseur de saisie, sélection de texte, icônes système, barre de statut.
  /// Sans ce drapeau, un thème sombre garde des réglages système clairs et
  /// laisse apparaître, ici et là, du gris clair sur gris clair.
  bool get isDark => surface.computeLuminance() < 0.5;
}

/// Les thèmes intégrés. Trois clairs (Ocre, Ardoise, Encre) et un **sombre**
/// ([sombre]), dont chaque couple texte/fond a été revalidé pour la nuit — un
/// thème sombre n'est pas un thème clair inversé (voir sa documentation).
class AppPalettes {
  AppPalettes._();

  /// Résout un identifiant en palette concrète.
  static AppPalette of(AppPaletteId id) => switch (id) {
    AppPaletteId.ocre => ocre,
    AppPaletteId.ardoise => ardoise,
    AppPaletteId.encre => encre,
    AppPaletteId.sombre => sombre,
  };

  /// Palette **intégrée** portant ce code, ou `null` si le code correspond à un
  /// thème personnalisé (créé par le super admin) : celui-là est dérivé de ses
  /// 3 couleurs par `PaletteBuilder`, pas réglé à la main ici.
  static AppPalette? byCode(String code) => switch (code) {
    'ocre' => ocre,
    'ardoise' => ardoise,
    'encre' => encre,
    'sombre' => sombre,
    _ => null,
  };

  /// Le thème sombre **intégré**, cible du bouton clair/sombre.
  /// Le code est celui persisté en base ; il ne doit pas changer.
  static const String sombreCode = 'sombre';

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

  // ═══════════════════════════════════════════════════════════════════════════
  // SOMBRE — le pendant nocturne d'Ardoise (même famille bleu-pétrole froide).
  //
  // ## Un thème sombre n'est pas un thème clair inversé
  //
  // Quatre règles gouvernent les valeurs ci-dessous. Elles ne sont pas
  // décoratives : chacune corrige un défaut concret qu'on obtient en se
  // contentant d'inverser les couleurs.
  //
  // 1. **L'élévation monte vers le clair.** En thème clair, une carte est plus
  //    claire que la page (blanc sur plâtre). En thème sombre, c'est
  //    l'inverse : une carte plus SOMBRE que la page se lit comme un trou.
  //    Ici, `surface` (la page) est la couleur la plus foncée et chaque
  //    `surfaceContainer*` monte d'un cran vers le clair. Comme les écrans
  //    utilisent `surfaceContainerLowest` pour les cartes, les barres de titre
  //    et le menu, ces éléments se détachent automatiquement du fond.
  //
  // 2. **Ni noir pur, ni blanc pur.** Le fond n'est pas #000 (les ombres et
  //    les paliers d'élévation n'auraient plus de place en dessous) et le texte
  //    n'est pas #FFF : sur un fond très foncé, le blanc pur « vibre »
  //    (halation) et fatigue en lecture longue. On plafonne le texte principal
  //    à ~14:1 au lieu de 19:1, ce qui reste très au-dessus du AA exigé.
  //
  // 3. **Les couleurs d'accent s'éclaircissent.** Le pétrole #006685 d'Ardoise
  //    est illisible sur fond foncé (≈ 1.5:1) : il devient ici un bleu ciel
  //    #6DD2FE. Conséquence obligatoire : le texte POSÉ SUR cette couleur
  //    (`onPrimary`, `onError`, `onTertiary`…) devient **foncé**. Un bouton
  //    « Supprimer » est donc rose clair à texte sombre — c'est voulu, et c'est
  //    pourquoi aucun écran ne doit écrire `Colors.white` en dur sur un fond
  //    de couleur : il faut le token `on*` correspondant.
  //
  // 4. **Saturation contenue.** Une couleur très saturée sur fond foncé crée un
  //    halo (aberration chromatique). Les accents sont donc éclaircis *et*
  //    légèrement désaturés par rapport à leur équivalent clair.
  //
  // Les pastilles (`*Fixed`) suivent la même logique renversée : fond teinté
  // FONCÉ + texte clair, là où le thème clair a un fond pâle + texte foncé.
  // Tous les couples sont vérifiés par `test/theme/dark_palette_test.dart`.
  // ═══════════════════════════════════════════════════════════════════════════
  static const AppPalette sombre = AppPalette(
    // Le papier de nuit : bleu-gris très foncé, jamais noir (règle 2).
    surface: Color(0xFF0F1418),
    surfaceDim: Color(0xFF0A0E11),
    surfaceBright: Color(0xFF2C343B),
    // Les cartes/barres/menu montent d'un cran vers le clair (règle 1).
    surfaceContainerLowest: Color(0xFF171E23),
    surfaceContainerLow: Color(0xFF1C242A),
    surfaceContainer: Color(0xFF222B31),
    surfaceContainerHigh: Color(0xFF29333A),
    surfaceContainerHighest: Color(0xFF313C43),
    // Blanc cassé légèrement froid : ~14:1 sur la page, sans halation.
    onSurface: Color(0xFFE2E8EC),
    // Texte secondaire : encore du texte (libellés, légendes) → ≥ 4.5:1 même
    // sur le fond le plus clair de la famille (`surfaceContainerHighest`).
    onSurfaceVariant: Color(0xFFAFBBC3),
    // Snackbar & co : en thème sombre, l'« inverse » est une boîte CLAIRE.
    inverseSurface: Color(0xFFE2E8EC),
    inverseOnSurface: Color(0xFF1C242A),
    outline: Color(0xFF7B888F), // ≥ 3:1 sur la page (élément d'interface)
    outlineVariant: Color(0xFF3B454C), // bordure discrète des cartes
    surfaceTint: Color(0xFF6DD2FE),
    surfaceVariant: Color(0xFF313C43),

    // Bleu ciel : l'action, et aussi la couleur des liens et des libellés
    // d'onglet actif → vérifiée comme du TEXTE sur la page (≈ 10:1).
    primary: Color(0xFF6DD2FE),
    onPrimary: Color(0xFF00344A), // texte foncé sur bouton plein (règle 3)
    primaryContainer: Color(0xFF00587A),
    onPrimaryContainer: Color(0xFFC7EAFF),
    inversePrimary: Color(0xFF005671),
    // Pastille = fond teinté FONCÉ + texte clair. Sert aussi de fond aux items
    // de menu sélectionnés (`AppColors.navItemSelected`, composé en alpha).
    primaryFixed: Color(0xFF0E3D52),
    primaryFixedDim: Color(0xFF11506C),
    onPrimaryFixed: Color(0xFFD5F0FF),
    onPrimaryFixedVariant: Color(0xFFA6DCF6),

    // Ambre — l'information, l'état. Éclairci depuis le #795900 d'Ardoise.
    secondary: Color(0xFFF0C662),
    onSecondary: Color(0xFF3D2E00),
    secondaryContainer: Color(0xFF5C4400),
    onSecondaryContainer: Color(0xFFFFE0A3),
    secondaryFixed: Color(0xFF453413),
    secondaryFixedDim: Color(0xFF5C4712),
    onSecondaryFixed: Color(0xFFFFE3AE),
    onSecondaryFixedVariant: Color(0xFFEBC77C),

    // Vert — validé / signé / payé. `tertiaryFixed` est le fond du bouton
    // « Enregistrer » : foncé, avec `onTertiaryFixed` clair par-dessus.
    tertiary: Color(0xFFA2DC66),
    onTertiary: Color(0xFF1D3600),
    tertiaryContainer: Color(0xFF2F5300),
    onTertiaryContainer: Color(0xFFC1F58A),
    tertiaryFixed: Color(0xFF1F3D12),
    tertiaryFixedDim: Color(0xFF2C5019),
    onTertiaryFixed: Color(0xFFC6EFA1),
    onTertiaryFixedVariant: Color(0xFFA2DC66),

    // Rouge — danger. Clair sur fond sombre, donc texte foncé par-dessus.
    error: Color(0xFFFFB3AC),
    onError: Color(0xFF5F1310),
    errorContainer: Color(0xFF8C1A17),
    onErrorContainer: Color(0xFFFFDAD6),

    // L'ombre ne « pose » plus rien en thème sombre (c'est l'élévation vers le
    // clair qui joue ce rôle) : on la garde très discrète.
    shadowTint: Color(0xFF000508),
  );
}
