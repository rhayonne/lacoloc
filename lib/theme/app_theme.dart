import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Tema unificado do app. Componentes Flutter herdam daqui automaticamente,
/// então alterar uma cor/fonte aqui propaga para toda a aplicação.
///
/// ── ONDE CADA COISA É USADA ─────────────────────────────────────────────────
/// **Tokens de cor** ficam em [AppColors]; **espaçamentos** em `AppSpacing`;
/// **raios** em `AppRadius`; **tipografia** em `AppTypography`. Aqui só montamos
/// o [ThemeData] e alguns *styles* de botão nomeados.
///
/// `AppTheme.light` (usado no `MaterialApp`) define os defaults herdados:
///   • `elevatedButtonTheme` / `filledButtonTheme` → botões primários (azul
///     `AppColors.primary`) — ação principal padrão.
///   • `outlinedButtonTheme` → botões secundários bordés (contorno cinza).
///   • `textButtonTheme` → ações discretas (liens).
///   • `inputDecorationTheme` → aparência de TODOS os campos de formulário
///     (borda, foco azul, erro vermelho).
///   • `cardTheme`, `dialogTheme`, `chipTheme`, `snackBarTheme`, etc. → cada
///     componente Material correspondente.
///
/// **Styles de botão nomeados** (aplicar explicitamente no botão):
///   • [saveButtonStyle]     → botão « Enregistrer / Sauvegarder » (vert clair,
///                             `tertiaryFixed`). Semântica de sucesso/positiva.
///   • [cancelButtonStyle]   → botão « Annuler / Fermer » (bordé neutre).
///   • [deleteButtonStyle]   → botão « Supprimer » (rouge `AppColors.error`).
///   • [editButtonStyle]     → botão « Modifier » / édição (bordé bleu primaire).
///   • [documentButtonStyle] → botão « Document » / impressão PDF (bordé azul),
///                             via o widget `DocumentPdfButton`.
/// Cor de **sucesso** (selos, ícones ✓) = `AppColors.success` (verde, calcado
/// no Tertiary). Cor de **hover de célula** (agenda) = `AppColors.hoverCell`.
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = AppColors.lightScheme;
    final textTheme = AppTypography.textTheme;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: AppColors.background,

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceContainerLowest,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        titleTextStyle: AppTypography.titleLg,
        iconTheme: IconThemeData(color: AppColors.onSurface),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 1,
          shadowColor: AppColors.shadowTint.withValues(alpha: 0.15),
          textStyle: AppTypography.labelMd,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          minimumSize: const Size(0, 48),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: BorderSide(color: AppColors.outlineVariant),
          textStyle: AppTypography.labelMd,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          minimumSize: const Size(0, 48),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTypography.labelMd,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          textStyle: AppTypography.labelMd,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
          minimumSize: const Size(0, 48),
        ),
      ),

      // ── Onglets (TabBar) — style « groupe de boutons » STANDARD du système ──
      // Rendu unique appliqué à TOUTES les `TabBar` de tous les profils
      // (proprietaire, locataire, super admin). Aucune `TabBar` ne doit
      // surcharger `indicator` / `labelColor` : elles héritent d'ici pour rester
      // cohérentes. Pour changer l'allure des onglets partout, MODIFIER ICI.
      //
      // Les onglets doivent se lire comme des **boutons** (et non comme une
      // simple ligne de mots) : chaque `TabBar` est enveloppée dans le widget
      // [AppTabBar] ([lib/theme/app_tab_bar.dart]) qui ajoute une **piste**
      // (fond clair + bord + coins arrondis = « segmented control »). Ici, le
      // thème définit la **pastille** de l'onglet actif :
      //  • onglet **sélectionné** = pastille pleine couleur primaire (teal),
      //    entièrement arrondie, libellé **blanc** et gras ;
      //  • onglets **non sélectionnés** = libellé discret
      //    ([AppColors.onSurfaceVariant]), posés dans la piste.
      // `indicatorSize: tab` fait remplir tout l'onglet par la pastille ; le
      // trait séparateur natif est retiré (la piste structure déjà la barre).
      tabBarTheme: TabBarThemeData(
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        labelColor: AppColors.onPrimary,
        unselectedLabelColor: AppColors.onSurfaceVariant,
        labelStyle: AppTypography.labelMd.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: AppTypography.labelMd,
        overlayColor: WidgetStatePropertyAll(
          AppColors.primary.withValues(alpha: 0.06),
        ),
      ),

      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLowest,
        elevation: 1,
        shadowColor: AppColors.shadowTint.withValues(alpha: 0.08),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.borderMd,
          side: BorderSide(color: AppColors.outlineVariant, width: 1),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
        labelStyle: AppTypography.labelMd.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        labelStyle: AppTypography.labelSm,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
        side: BorderSide(color: AppColors.outlineVariant),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        titleTextStyle: AppTypography.titleLg,
        contentTextStyle: AppTypography.bodyMd,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inverseSurface,
        contentTextStyle: AppTypography.bodyMd.copyWith(
          color: AppColors.inverseOnSurface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
      ),

      iconTheme: IconThemeData(color: AppColors.onSurfaceVariant),
    );
  }

  /// Élévation/ombre standard des boutons "flottants" légers de l'app (ex.
  /// [FilterButton]) : donne l'impression que le bouton est légèrement
  /// détaché du fond. Centralisé ici pour être répliqué partout à l'identique.
  static const double raisedButtonElevation = 1.5;
  static Color get raisedButtonShadowColor => Colors.black.withValues(alpha: 0.3);

  /// Style bordé pour tous les boutons "Annuler" de l'app.
  static ButtonStyle get cancelButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.onSurfaceVariant,
    side: BorderSide(color: AppColors.outlineVariant),
    textStyle: AppTypography.labelMd,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
    minimumSize: const Size(0, 48),
  );

  /// Style vert clair pour tous les boutons "Sauvegarder" de l'app.
  static ButtonStyle get saveButtonStyle => FilledButton.styleFrom(
    backgroundColor: AppColors.tertiaryFixed,
    foregroundColor: AppColors.onTertiaryFixed,
    textStyle: AppTypography.labelMd,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
    minimumSize: const Size(0, 48),
  );

  /// Style rouge pour tous les boutons "Supprimer" de l'app.
  static ButtonStyle get deleteButtonStyle => FilledButton.styleFrom(
    backgroundColor: AppColors.error,
    foregroundColor: Colors.white,
    textStyle: AppTypography.labelMd,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
    minimumSize: const Size(0, 48),
  );

  /// Style bordé (couleur primaire) pour tous les boutons "Modifier" / édition
  /// de l'app. Action secondaire distincte du vert « Enregistrer » : bord bleu
  /// primaire. À utiliser sur tout bouton « Modifier » (avec `Icons.edit_outlined`).
  static ButtonStyle get editButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: BorderSide(color: AppColors.primary),
    textStyle: AppTypography.labelMd,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
    minimumSize: const Size(0, 48),
  );

  /// Style bordé (couleur primaire) pour tous les boutons "Document" / impression
  /// PDF de l'app. À utiliser via le widget [DocumentPdfButton].
  static ButtonStyle get documentButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: AppColors.primary,
    side: BorderSide(color: AppColors.primary),
    textStyle: AppTypography.labelMd,
    padding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.lg,
      vertical: AppSpacing.md,
    ),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
    minimumSize: const Size(0, 48),
  );

  // ── Barre de titre standard (AppTopBar / FormPageHeader) ───────────────────
  /// Décoration **standard** d'une barre de titre : fond distinct du fond de
  /// page ([AppColors.barBackground]) + **ombre portée** en bas
  /// ([AppColors.barShadow]). Toute barre de titre du système doit l'utiliser
  /// (via le widget `AppTopBar`), pour un rendu uniforme et modifiable ici.
  static BoxDecoration get barDecoration => BoxDecoration(
    color: AppColors.barBackground,
    boxShadow: [
      BoxShadow(
        color: AppColors.barShadow,
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
