import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/data/models/profile_visibility.dart';

/// Une demande telle que PostgREST la renvoie **depuis la refonte** : plus
/// aucun embed `Users_Client`. L'identité de la contrepartie vient de la RPC
/// `demande_counterpart_profiles`.
Map<String, dynamic> _row({Map<String, dynamic>? extra}) => {
      'id': 7,
      'created_at': '2026-08-10T20:52:00.000Z',
      'locataire_id': 'loc-1',
      'chambre_id': 3,
      'immeuble_id': 9,
      'contact_etabli': true,
      'statut': 'repondu',
      'Chambres': {'room_name': 'Chambre 1'},
      'Immeubles': {'name': 'APT test coloc', 'owner_id': 'prop-1'},
      ...?extra,
    };

void main() {
  group('DemandeContactModel — ne transporte aucune donnée personnelle', () {
    test('lit le contexte du fil (bien, parties, statut)', () {
      final d = DemandeContactModel.fromJson(_row());

      expect(d.id, 7);
      expect(d.locataireId, 'loc-1');
      expect(d.proprietaireId, 'prop-1');
      expect(d.bienLabel, 'Chambre 1 — APT test coloc');
      expect(d.statut, StatutDemande.repondu);
    });

    test('résout l’interlocuteur par son id, sans exposer sa fiche', () {
      final d = DemandeContactModel.fromJson(_row());

      expect(d.interlocuteurId('loc-1'), 'prop-1');
      expect(d.interlocuteurId('prop-1'), 'loc-1');
      expect(d.interlocuteurId('tiers'), isNull);
      expect(d.interlocuteurId(null), isNull);
    });

    test('ignore un embed Users_Client qui traînerait dans la réponse', () {
      // Garde-fou : si quelqu'un remet un embed dans le `select`, le modèle ne
      // doit toujours pas véhiculer de coordonnées — elles doivent passer par
      // la RPC qui applique les préférences côté serveur.
      final d = DemandeContactModel.fromJson(_row(extra: {
        'Users_Client': {
          'full_name': 'Novo Locataire',
          'email': 'locataire@loc.com',
          'phone': '+330584956241',
        },
      }));

      expect(d.bienLabel, 'Chambre 1 — APT test coloc');
      // Le modèle n'a tout simplement pas d'API pour ces champs (compile-time),
      // et rien n'en est dérivé ici.
      expect(d.toString(), isNot(contains('locataire@loc.com')));
    });

    test('copyWith conserve le contexte', () {
      final d = DemandeContactModel.fromJson(_row())
          .copyWith(statut: StatutDemande.ignore);

      expect(d.statut, StatutDemande.ignore);
      expect(d.bienLabel, 'Chambre 1 — APT test coloc');
      expect(d.proprietaireId, 'prop-1');
    });
  });

  group('ProfileCardData.preFiltered — sortie de la RPC', () {
    test('n’affiche que les champs réellement renvoyés', () {
      // Le serveur a masqué le téléphone : il arrive à null.
      final p = ProfileCardData.preFiltered(
        userId: 'prop-1',
        fullName: 'Le Proprietaire',
        email: 'prop@prop.com',
        phone: null,
        age: null,
      );

      expect(p.visibleFields.keys, [ProfileVisibilityField.email]);
      expect(p.phone, isNull);
    });

    test('tout masqué → fiche sans champ, mais avec le nom', () {
      final p = ProfileCardData.preFiltered(
        userId: 'prop-1',
        fullName: 'Le Proprietaire',
      );

      expect(p.visibleFields, isEmpty);
      expect(p.fullName, 'Le Proprietaire');
    });

    test('withSubtitle ajoute le bien sans toucher au reste', () {
      final p = ProfileCardData.preFiltered(
        fullName: 'Novo Locataire',
        phone: '+330584956241',
        age: 25,
      ).withSubtitle('Chambre 1 — APT test coloc');

      expect(p.subtitle, 'Chambre 1 — APT test coloc');
      expect(p.visibleFields[ProfileVisibilityField.age], '25 ans');
      expect(p.visibleFields[ProfileVisibilityField.phone], '+330584956241');
    });
  });

  group('ProfileCardData.fromUsersClient — aperçu de sa propre fiche', () {
    test('applique les préférences localement (aperçu Mon Profil)', () {
      final p = ProfileCardData(
        userId: 'x',
        fullName: 'Jean Dupont',
        phone: '+33600000000',
        email: 'jean@x.fr',
        age: 40,
        visibility: const ProfileVisibility(phone: false),
      );

      expect(p.phone, isNull);
      expect(p.visibleFields[ProfileVisibilityField.age], '40 ans');
      expect(p.visibleFields[ProfileVisibilityField.email], 'jean@x.fr');
    });

    test('un champ visible mais vide n’est pas listé', () {
      final p = ProfileCardData(fullName: 'Jean', phone: '', email: null);
      expect(p.visibleFields, isEmpty);
    });
  });

  test('initiales : prénom + nom, sinon 1 lettre, sinon « ? »', () {
    expect(ProfileCardData.initials('Novo Locataire'), 'NL');
    expect(ProfileCardData.initials('Jean'), 'J');
    expect(ProfileCardData.initials(null), '?');
    expect(ProfileCardData.initials('   '), '?');
  });
}
