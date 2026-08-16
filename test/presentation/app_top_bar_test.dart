import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/presentation/widgets/app_button.dart';
import 'package:habitafrance/presentation/widgets/app_top_bar.dart';

Future<double> _hauteurBarre(
  WidgetTester tester, {
  Widget? trailing,
  double width = 1200,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: Column(
            children: [AppTopBar(title: 'Écran', trailing: trailing)],
          ),
        ),
      ),
    ),
  );
  return tester.getSize(find.byType(AppTopBar)).height;
}

void main() {
  group('AppTopBar — un seul gabarit pour tout l’app', () {
    testWidgets('la barre sans action a la même hauteur qu’avec des boutons',
        (tester) async {
      // C'est la régression signalée : « Messages » (sans bouton) rendait une
      // barre plus basse que « Mes Propriétés » (avec boutons), donc la mise en
      // page sautait en changeant de menu.
      final sansAction = await _hauteurBarre(tester);
      final avecAction = await _hauteurBarre(
        tester,
        trailing: AppButton.primary(
          icon: Icons.add,
          label: 'Ajouter',
          onPressed: () {},
        ),
      );

      expect(sansAction, avecAction);
    });

    testWidgets('le titre et les actions cohabitent sur une ligne en large',
        (tester) async {
      await _hauteurBarre(
        tester,
        trailing: AppButton.primary(
          icon: Icons.add,
          label: 'Ajouter',
          onPressed: () {},
        ),
      );

      final titre = tester.getRect(find.text('Écran'));
      final bouton = tester.getRect(find.text('Ajouter'));
      expect(bouton.left, greaterThan(titre.right),
          reason: 'les actions sont à droite du titre, pas en dessous');
    });

    testWidgets('en étroit, les actions passent sous le titre sans déborder',
        (tester) async {
      await _hauteurBarre(
        tester,
        width: 420,
        trailing: AppButton.primary(
          icon: Icons.add,
          label: 'Ajouter',
          onPressed: () {},
        ),
      );

      final titre = tester.getRect(find.text('Écran'));
      final bouton = tester.getRect(find.text('Ajouter'));
      expect(bouton.top, greaterThan(titre.top));
      expect(tester.takeException(), isNull);
    });

    testWidgets('un sous-titre ne casse pas le gabarit', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppTopBar(title: 'Écran', subtitle: 'Contexte'),
          ),
        ),
      );

      expect(find.text('Contexte'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
