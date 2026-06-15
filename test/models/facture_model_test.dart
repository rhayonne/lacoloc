import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/models/facture.dart';

void main() {
  group('FactureModel', () {
    group('fromMap', () {
      test('parseia campos obrigatórios', () {
        final map = {
          'id': 1,
          'owner_id': 'uid-owner',
          'fournisseur': 'EDF',
          'type_facture': 'Électricité',
          'taux_tva': 20.0,
          'statut': 'Non payée',
        };

        final model = FactureModel.fromMap(map);

        expect(model.id, 1);
        expect(model.ownerId, 'uid-owner');
        expect(model.fournisseur, 'EDF');
        expect(model.typeFacture, 'Électricité');
        expect(model.tauxTva, 20.0);
        expect(model.statut, 'Non payée');
      });

      test('usa defaults quando campos opcionais ausentes', () {
        final map = {
          'id': 2,
          'owner_id': 'uid',
          'fournisseur': 'GDF',
          'type_facture': 'Gaz',
        };

        final model = FactureModel.fromMap(map);

        expect(model.tauxTva, 20.0);
        expect(model.statut, 'Non payée');
        expect(model.immeubleId, isNull);
        expect(model.chambreId, isNull);
        expect(model.montantHt, isNull);
        expect(model.montantTtc, isNull);
        expect(model.periodeDebut, isNull);
        expect(model.periodeFin, isNull);
        expect(model.dateEmission, isNull);
        expect(model.dateEcheance, isNull);
      });

      test('parseia campos opcionais', () {
        final map = {
          'id': 3,
          'owner_id': 'uid',
          'fournisseur': 'Saur',
          'type_facture': 'Eau',
          'taux_tva': 5.5,
          'statut': 'Payée',
          'immeuble_id': 10,
          'chambre_id': 4,
          'code_facture': 'FAC-2025-001',
          'montant_ht': 100.0,
          'montant_ttc': 105.5,
          'notes': 'Paiement en attente',
          'periode_debut': '2025-01-01',
          'periode_fin': '2025-01-31',
          'date_emission': '2025-02-01',
          'date_echeance': '2025-02-28',
          'created_at': '2025-02-01T08:00:00.000Z',
        };

        final model = FactureModel.fromMap(map);

        expect(model.tauxTva, 5.5);
        expect(model.statut, 'Payée');
        expect(model.immeubleId, 10);
        expect(model.chambreId, 4);
        expect(model.codeFacture, 'FAC-2025-001');
        expect(model.montantHt, 100.0);
        expect(model.montantTtc, 105.5);
        expect(model.notes, 'Paiement en attente');
        expect(model.periodeDebut, DateTime(2025, 1, 1));
        expect(model.periodeFin, DateTime(2025, 1, 31));
        expect(model.dateEmission, DateTime(2025, 2, 1));
        expect(model.dateEcheance, DateTime(2025, 2, 28));
      });

      test('parseia embed Immeubles', () {
        final map = {
          'id': 4,
          'owner_id': 'uid',
          'fournisseur': 'Veolia',
          'type_facture': 'Eau',
          'Immeubles': {'name': 'Résidence Soleil'},
        };

        final model = FactureModel.fromMap(map);
        expect(model.immeubleName, 'Résidence Soleil');
      });

      test('parseia embed Chambres', () {
        final map = {
          'id': 5,
          'owner_id': 'uid',
          'fournisseur': 'Orange',
          'type_facture': 'Internet',
          'Chambres': {'room_name': 'Chambre 3'},
        };

        final model = FactureModel.fromMap(map);
        expect(model.chambreName, 'Chambre 3');
      });

      test('immeubleName e chambreName são null sem embed', () {
        final map = {
          'id': 6,
          'owner_id': 'uid',
          'fournisseur': 'SFR',
          'type_facture': 'Téléphone',
        };

        final model = FactureModel.fromMap(map);
        expect(model.immeubleName, isNull);
        expect(model.chambreName, isNull);
      });
    });

    group('toInsert', () {
      test('inclui campos obrigatórios', () {
        const model = FactureModel(
          id: 1,
          ownerId: 'uid',
          fournisseur: 'EDF',
          typeFacture: 'Électricité',
        );

        final map = model.toInsert();

        expect(map['owner_id'], 'uid');
        expect(map['fournisseur'], 'EDF');
        expect(map['type_facture'], 'Électricité');
        expect(map['taux_tva'], 20.0);
        expect(map['statut'], 'Non payée');
      });

      test('omite campos null opcionais', () {
        const model = FactureModel(
          id: 1,
          ownerId: 'uid',
          fournisseur: 'Test',
          typeFacture: 'Divers',
        );

        final map = model.toInsert();

        expect(map.containsKey('immeuble_id'), isFalse);
        expect(map.containsKey('code_facture'), isFalse);
        expect(map.containsKey('montant_ht'), isFalse);
        expect(map.containsKey('montant_ttc'), isFalse);
        expect(map.containsKey('notes'), isFalse);
        expect(map.containsKey('periode_debut'), isFalse);
        expect(map.containsKey('date_emission'), isFalse);
      });

      test('formata datas como YYYY-MM-DD', () {
        final model = FactureModel(
          id: 1,
          ownerId: 'uid',
          fournisseur: 'Test',
          typeFacture: 'Eau',
          periodeDebut: DateTime(2025, 6, 1),
          periodeFin: DateTime(2025, 6, 30),
          dateEmission: DateTime(2025, 7, 1),
          dateEcheance: DateTime(2025, 7, 15),
        );

        final map = model.toInsert();

        expect(map['periode_debut'], '2025-06-01');
        expect(map['periode_fin'], '2025-06-30');
        expect(map['date_emission'], '2025-07-01');
        expect(map['date_echeance'], '2025-07-15');
      });

      test('chambre_id é incluído mesmo null', () {
        const model = FactureModel(
          id: 1,
          ownerId: 'uid',
          fournisseur: 'Test',
          typeFacture: 'Divers',
          chambreId: null,
        );

        final map = model.toInsert();
        expect(map.containsKey('chambre_id'), isTrue);
        expect(map['chambre_id'], isNull);
      });
    });

    group('constantes', () {
      test('kTypesFacture contém os tipos esperados', () {
        expect(kTypesFacture, contains('Eau'));
        expect(kTypesFacture, contains('Électricité'));
        expect(kTypesFacture, contains('Gaz'));
        expect(kTypesFacture, contains('Assurance'));
        expect(kTypesFacture, contains('Internet'));
        expect(kTypesFacture.length, greaterThanOrEqualTo(8));
      });

      test('kStatutsFacture contém os 3 statuts', () {
        expect(kStatutsFacture, containsAll(['Non payée', 'Payée', 'En litige']));
        expect(kStatutsFacture, hasLength(3));
      });
    });
  });
}
