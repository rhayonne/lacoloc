import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/presentation/messagerie/messagerie_model.dart';
import 'package:habitafrance/presentation/messagerie/messagerie_row.dart';

DemandeContactModel _demande({StatutDemande statut = StatutDemande.repondu}) =>
    DemandeContactModel.fromJson({
      'id': 1,
      'created_at': '2026-08-10T20:52:00.000Z',
      'locataire_id': 'loc-1',
      'chambre_id': 3,
      'immeuble_id': 9,
      'contact_etabli': true,
      'statut': statut.code,
      'Chambres': {'room_name': 'Chambre 1'},
      'Immeubles': {'name': 'APT test coloc', 'owner_id': 'prop-1'},
    });

Future<void> _pumpRow(
  WidgetTester tester, {
  String? nomInterlocuteur = 'Novo Locataire',
  required MessagerieRole role,
  required double width,
  VoidCallback? onDiscuter,
  VoidCallback? onTap,
  int unread = 0,
}) async {
  tester.view.physicalSize = Size(width, 400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: MessagerieRow(
            demande: _demande(),
            profil: nomInterlocuteur == null
                ? null
                : ProfileCardData.preFiltered(fullName: nomInterlocuteur),
            config: MessagerieRoleConfig(role),
            selected: false,
            unread: unread,
            snippet: 'Boa tarde',
            onTap: onTap ?? () {},
            onDiscuter: onDiscuter ?? () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('affiche l’interlocuteur fourni par le serveur — côté proprio',
      (tester) async {
    await _pumpRow(tester, role: MessagerieRole.proprietaire, width: 800);

    expect(find.text('Novo Locataire'), findsOneWidget);
  });

  testWidgets('affiche l’interlocuteur fourni par le serveur — côté locataire',
      (tester) async {
    await _pumpRow(
      tester,
      nomInterlocuteur: 'Le Proprietaire',
      role: MessagerieRole.locataire,
      width: 800,
    );

    expect(find.text('Le Proprietaire'), findsOneWidget);
  });

  testWidgets('fiche pas encore chargée → le bien reste lisible, pas de faux '
      'nom', (tester) async {
    await _pumpRow(
      tester,
      nomInterlocuteur: null,
      role: MessagerieRole.proprietaire,
      width: 800,
    );

    expect(find.text('Chambre 1 — APT test coloc'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
  });

  testWidgets('le bien et l’extrait du fil sont affichés', (tester) async {
    await _pumpRow(
        tester, role: MessagerieRole.proprietaire, width: 800);

    expect(find.text('Chambre 1 — APT test coloc'), findsOneWidget);
    expect(find.text('« Boa tarde »'), findsOneWidget);
  });

  testWidgets('le bouton Discuter est libellé en large', (tester) async {
    await _pumpRow(
        tester, role: MessagerieRole.proprietaire, width: 800);

    expect(find.text('Discuter'), findsOneWidget);
  });

  testWidgets('en étroit, le bouton devient une icône (cible ≥ 44 px)',
      (tester) async {
    await _pumpRow(
        tester, role: MessagerieRole.locataire, width: 380);

    expect(find.text('Discuter'), findsNothing);
    final size = tester.getSize(find.byType(IconButton).first);
    expect(size.width, greaterThanOrEqualTo(44));
    expect(size.height, greaterThanOrEqualTo(44));
  });

  testWidgets('le bouton ouvre le fil sans sélectionner la ligne',
      (tester) async {
    var discuter = 0;
    var tap = 0;
    await _pumpRow(
      tester,
      role: MessagerieRole.proprietaire,
      width: 800,
      onDiscuter: () => discuter++,
      onTap: () => tap++,
    );

    await tester.tap(find.text('Discuter'));
    expect(discuter, 1);
    expect(tap, 0, reason: 'le bouton ne doit pas déclencher la ligne');
  });

  testWidgets('cliquer la ligne ouvre la fiche de profil', (tester) async {
    var tap = 0;
    await _pumpRow(
      tester,
      role: MessagerieRole.proprietaire,
      width: 800,
      onTap: () => tap++,
    );

    await tester.tap(find.text('Chambre 1 — APT test coloc'));
    expect(tap, 1);
  });

  testWidgets('le libellé d’état suit le rôle', (tester) async {
    await _pumpRow(
        tester, role: MessagerieRole.proprietaire, width: 800);
    expect(find.text('Répondu'), findsOneWidget);
  });

  testWidgets('aucun débordement sur mobile étroit', (tester) async {
    await _pumpRow(
        tester, role: MessagerieRole.locataire, width: 320);
    expect(tester.takeException(), isNull);
  });
}
