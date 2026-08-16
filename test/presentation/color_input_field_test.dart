import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/presentation/widgets/color_input_field.dart';

Future<void> _pump(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: ColorInputField(
            label: 'Fond de page',
            usage: 'Le papier : le fond de toutes les pages.',
            onChanged: (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('ColorInputField — le sélecteur de format ne déborde pas', () {
    // Régression : le bouton se dimensionnait sur l'item le plus large
    // (« iOS / macOS ») et débordait de sa largeur imposée, ce qui affichait
    // « RIGHT OVERFLOWED BY 29 PIXELS » par-dessus le dialogue.
    testWidgets('dans un dialogue étroit (largeur réelle du pop-up)',
        (tester) async {
      await _pump(tester, 420);
      expect(tester.takeException(), isNull);
    });

    testWidgets('juste au-dessus du seuil de bascule en colonne',
        (tester) async {
      await _pump(tester, 384);
      expect(tester.takeException(), isNull);
    });

    testWidgets('en pleine largeur', (tester) async {
      await _pump(tester, 900);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sous le seuil, format et code s’empilent', (tester) async {
      await _pump(tester, 360);
      expect(tester.takeException(), isNull);
      final format = tester.getRect(find.text('Format'));
      final code = tester.getRect(find.text('Code couleur'));
      expect(code.top, greaterThan(format.top));
    });
  });
}
