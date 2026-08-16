import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/demande_contact.dart';
import 'package:habitafrance/data/models/profile_card_data.dart';
import 'package:habitafrance/presentation/messagerie/messagerie_model.dart';

DemandeContactModel _d({
  required int id,
  required StatutDemande statut,
  String chambre = 'Chambre 1',
}) =>
    DemandeContactModel.fromJson({
      'id': id,
      'created_at': '2026-08-10T20:52:00.000Z',
      'locataire_id': 'loc-1',
      'chambre_id': 3,
      'immeuble_id': 9,
      'contact_etabli': true,
      'statut': statut.code,
      'Chambres': {'room_name': chambre},
      'Immeubles': {'name': 'APT test coloc', 'owner_id': 'prop-1'},
    });

/// Fiches telles que les renvoie `demande_counterpart_profiles`.
Map<int, ProfileCardData> _profils(Map<int, String> noms) => {
      for (final e in noms.entries)
        e.key: ProfileCardData.preFiltered(fullName: e.value),
    };

void main() {
  group('MessagerieRoleConfig', () {
    test('le propriétaire a les 4 statuts détaillés', () {
      const c = MessagerieRoleConfig(MessagerieRole.proprietaire);
      expect(c.filters.map((f) => f.label),
          ['Nouveau', 'Non répondu', 'Répondu', 'Ignoré']);
      expect(c.canManageStatut, isTrue);
    });

    test('le locataire ne voit que « en attente » / « répondu »', () {
      const c = MessagerieRoleConfig(MessagerieRole.locataire);
      expect(c.filters.map((f) => f.label), ['En attente', 'Répondu']);
      expect(c.canManageStatut, isFalse);
    });

    test('« ignoré » reste « en attente » côté locataire (pas de vexation)',
        () {
      const c = MessagerieRoleConfig(MessagerieRole.locataire);
      expect(c.statutLabel(_d(id: 1, statut: StatutDemande.ignore)),
          'En attente');
      expect(c.statutLabel(_d(id: 1, statut: StatutDemande.repondu)),
          'Répondu');
    });

    test('le propriétaire garde le libellé exact du statut', () {
      const c = MessagerieRoleConfig(MessagerieRole.proprietaire);
      expect(c.statutLabel(_d(id: 1, statut: StatutDemande.ignore)), 'Ignoré');
    });
  });

  group('filterDemandes', () {
    final demandes = [
      _d(id: 1, statut: StatutDemande.nouveau),
      _d(id: 2, statut: StatutDemande.repondu),
      _d(id: 3, statut: StatutDemande.ignore),
    ];
    final noms = _profils({
      1: 'Alice Martin',
      2: 'Bob Durand',
      3: 'Carla Petit',
    });

    test('sans filtre ni recherche, tout passe', () {
      expect(filterDemandes(demandes: demandes).length, 3);
    });

    test('filtre par statut', () {
      const f = MessagerieStatutFilter(
          label: 'Répondu', statuts: {StatutDemande.repondu});
      final out = filterDemandes(demandes: demandes, statutFilter: f);
      expect(out.map((d) => d.id), [2]);
    });

    test('recherche par nom de l’interlocuteur', () {
      final out =
          filterDemandes(demandes: demandes, profils: noms, query: 'bob');
      expect(out.map((d) => d.id), [2]);
    });

    test('sans fiche chargée, la recherche par nom ne trouve rien — elle '
        'n’invente pas d’identité', () {
      expect(filterDemandes(demandes: demandes, query: 'bob'), isEmpty);
    });

    test('cherche le nom, jamais les coordonnées masquées', () {
      // Une fiche dont le serveur a retiré le téléphone : chercher ce numéro
      // ne doit pas permettre de retrouver la personne.
      final profils = {
        2: ProfileCardData.preFiltered(fullName: 'Bob Durand', phone: null),
      };
      expect(
        filterDemandes(
            demandes: demandes, profils: profils, query: '0612345678'),
        isEmpty,
      );
    });

    test('recherche dans le contenu des messages', () {
      final out = filterDemandes(
        demandes: demandes,
        profils: noms,
        query: 'boa tarde',
        searchText: {2: 'Boa tarde, je suis intéressé'},
      );
      expect(out.map((d) => d.id), [2]);
    });

    test('recherche par bien (chambre / immeuble)', () {
      final out =
          filterDemandes(demandes: demandes, profils: noms, query: 'apt test');
      expect(out.length, 3);
    });

    test('recherche insensible à la casse et aux espaces autour', () {
      final out =
          filterDemandes(demandes: demandes, profils: noms, query: '  BOB ');
      expect(out.map((d) => d.id), [2]);
    });

    test('statut + recherche se combinent', () {
      const f = MessagerieStatutFilter(
          label: 'Répondu', statuts: {StatutDemande.repondu});
      expect(
        filterDemandes(
            demandes: demandes,
            profils: noms,
            query: 'alice',
            statutFilter: f),
        isEmpty,
      );
    });
  });

  group('countByFilter', () {
    test('compte par onglet, indépendamment du filtre courant', () {
      final demandes = [
        _d(id: 1, statut: StatutDemande.nouveau),
        _d(id: 2, statut: StatutDemande.repondu),
        _d(id: 3, statut: StatutDemande.repondu),
      ];
      const c = MessagerieRoleConfig(MessagerieRole.locataire);
      final counts = countByFilter(demandes, c.filters);
      expect(counts['En attente'], 1);
      expect(counts['Répondu'], 2);
    });
  });
}
