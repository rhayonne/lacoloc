import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/data/models/profile_visibility.dart';
import 'package:habitafrance/presentation/widgets/user_profile_card.dart';

ProfileCardData _data({ProfileVisibility? visibility}) => ProfileCardData(
      userId: 'u1',
      fullName: 'Novo Locataire',
      subtitle: 'Chambre 1 — APT test coloc',
      phone: '+330584956241',
      email: 'locataire@loc.com',
      age: 25,
      visibility: visibility ?? ProfileVisibility.defaults,
    );

Future<void> _pump(
  WidgetTester tester,
  Widget card, {
  Size size = const Size(400, 800),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: card)));
}

void main() {
  testWidgets('affiche le nom, le sous-titre et les champs visibles',
      (tester) async {
    await _pump(tester, UserProfileCard(data: _data()));

    expect(find.text('Novo Locataire'), findsOneWidget);
    expect(find.text('Chambre 1 — APT test coloc'), findsOneWidget);
    expect(find.text('25 ans'), findsOneWidget);
    expect(find.text('+330584956241'), findsOneWidget);
    expect(find.text('locataire@loc.com'), findsOneWidget);
  });

  testWidgets('n’affiche pas un champ masqué par son propriétaire',
      (tester) async {
    await _pump(
      tester,
      UserProfileCard(
        data: _data(visibility: const ProfileVisibility(phone: false)),
      ),
    );

    expect(find.text('+330584956241'), findsNothing);
    expect(find.text('locataire@loc.com'), findsOneWidget);
    expect(find.text('Novo Locataire'), findsOneWidget,
        reason: 'le nom reste toujours affiché');
  });

  testWidgets('tout masqué → message explicite, pas une carte vide',
      (tester) async {
    await _pump(
      tester,
      UserProfileCard(
        data: _data(
          visibility: const ProfileVisibility(
            age: false,
            phone: false,
            email: false,
          ),
        ),
      ),
    );

    // Formulation neutre : elle vaut aussi bien pour un choix explicite que
    // pour le défaut d'un bailleur qui n'a rien réglé.
    expect(find.textContaining('Aucune coordonnée partagée'), findsOneWidget);
  });

  testWidgets('le bouton de fermeture est rendu et notifie', (tester) async {
    var closed = 0;
    await _pump(
      tester,
      UserProfileCard(data: _data(), onClose: () => closed++),
    );

    final btn = find.byTooltip('Fermer la fiche');
    expect(btn, findsOneWidget);
    await tester.tap(btn);
    expect(closed, 1);
  });

  testWidgets('sans onClose, aucun bouton de fermeture', (tester) async {
    await _pump(tester, UserProfileCard(data: _data()));
    expect(find.byTooltip('Fermer la fiche'), findsNothing);
  });

  testWidgets('les actions de pied de carte sont rendues', (tester) async {
    await _pump(
      tester,
      UserProfileCard(
        data: _data(),
        actions: [FilledButton(onPressed: () {}, child: const Text('Discuter'))],
      ),
    );

    expect(find.text('Discuter'), findsOneWidget);
  });

  testWidgets('reste utilisable sur un écran étroit (pas de débordement)',
      (tester) async {
    await _pump(
      tester,
      UserProfileCard(
        data: _data(),
        onClose: () {},
        actions: [FilledButton(onPressed: () {}, child: const Text('Discuter'))],
      ),
      size: const Size(320, 560),
    );

    expect(tester.takeException(), isNull);
  });
}
