import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habitafrance/theme/app_palette.dart';
import 'package:habitafrance/theme/app_theme.dart';
import 'package:habitafrance/theme/theme_controller.dart';

/// Les valeurs de la palette sombre sont vérifiées ailleurs
/// (`builtin_palettes_test.dart`). Ici on vérifie le **branchement** : est-ce
/// que le fait de choisir une palette sombre se propage vraiment jusqu'au
/// `ThemeData` que Material distribue aux composants ?
///
/// C'est le genre de chose qui casse en silence : la palette est impeccable, et
/// l'app reste claire parce qu'une valeur est restée figée quelque part.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Les styles passent par `AppTypography` → google_fonts, qui tenterait
  // d'aller chercher les polices sur le réseau pendant les tests (et se
  // plaindrait après coup d'un travail asynchrone en suspens). On ne teste pas
  // les polices ici, seulement les couleurs.
  GoogleFonts.config.allowRuntimeFetching = false;

  // `AppColors` lit un état global. On le remet en place après chaque test
  // pour ne pas teindre les suivants.
  final paletteInitiale = ThemeController.instance.value;
  tearDown(() => ThemeController.instance.value = paletteInitiale);

  ThemeData themeAvec(AppPalette p) {
    ThemeController.instance.value = p;
    return AppTheme.current;
  }

  testWidgets('la palette sombre produit un ColorScheme sombre', (tester) async {
    expect(themeAvec(AppPalettes.sombre).colorScheme.brightness,
        Brightness.dark);
    expect(themeAvec(AppPalettes.ardoise).colorScheme.brightness,
        Brightness.light);
  });

  testWidgets('le fond de page suit la palette', (tester) async {
    final t = themeAvec(AppPalettes.sombre);
    expect(t.scaffoldBackgroundColor, AppPalettes.sombre.surface);
    expect(t.scaffoldBackgroundColor.computeLuminance(), lessThan(0.1));
  });

  testWidgets('les cartes et barres se détachent du fond de page', (tester) async {
    final t = themeAvec(AppPalettes.sombre);
    // La carte est plus CLAIRE que la page (élévation vers le clair).
    expect(
      t.cardTheme.color!.computeLuminance(),
      greaterThan(t.scaffoldBackgroundColor.computeLuminance()),
    );
    expect(
      t.appBarTheme.backgroundColor!.computeLuminance(),
      greaterThan(t.scaffoldBackgroundColor.computeLuminance()),
    );
  });

  testWidgets('le texte par défaut est clair sur un thème sombre', (tester) async {
    final t = themeAvec(AppPalettes.sombre);
    for (final style in [
      t.textTheme.bodyMedium,
      t.textTheme.titleLarge,
      t.textTheme.labelMedium,
    ]) {
      expect(
        style!.color!.computeLuminance(),
        greaterThan(0.5),
        reason: 'un style de texte est resté foncé sur fond sombre',
      );
    }
  });

  testWidgets('le bouton Supprimer garde un libellé lisible dans les deux thèmes', (tester) async {
    // Il portait `Colors.white` en dur : lisible sur le rouge foncé du thème
    // clair, invisible sur le rouge clair du thème sombre.
    for (final p in [AppPalettes.ardoise, AppPalettes.sombre]) {
      ThemeController.instance.value = p;
      final fg = AppTheme.deleteButtonStyle
          .foregroundColor!
          .resolve(<WidgetState>{})!;
      final bg = AppTheme.deleteButtonStyle
          .backgroundColor!
          .resolve(<WidgetState>{})!;
      final lf = fg.computeLuminance(), lb = bg.computeLuminance();
      final ratio = (lf > lb)
          ? (lf + 0.05) / (lb + 0.05)
          : (lb + 0.05) / (lf + 0.05);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'libellé « Supprimer » à ${ratio.toStringAsFixed(2)}:1');
    }
  });

  testWidgets('un écran réel se peint bien en sombre', (tester) async {
    ThemeController.instance.value = AppPalettes.sombre;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.current,
        home: Scaffold(
          appBar: AppBar(title: const Text('Écran')),
          body: Column(
            children: [
              const Card(child: Text('Contenu')),
              FilledButton(onPressed: () {}, child: const Text('Action')),
              const TextField(),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    final scaffold = tester.widget<Material>(
      find.descendant(
        of: find.byType(Scaffold),
        matching: find.byType(Material),
      ).first,
    );
    expect(scaffold.color, AppPalettes.sombre.surface);

    // Le texte hérite bien d'une couleur claire (et non du noir par défaut
    // de Material, qui serait le symptôme d'un thème non transmis).
    final texte = tester.widget<Text>(find.text('Contenu'));
    final style = DefaultTextStyle.of(
      tester.element(find.text('Contenu')),
    ).style;
    expect(
      (texte.style?.color ?? style.color)!.computeLuminance(),
      greaterThan(0.5),
    );
  });
}
