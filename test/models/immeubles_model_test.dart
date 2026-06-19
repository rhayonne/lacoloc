import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/models/immeubles.dart';
import 'package:lacoloc_front/data/models/immeuble_type.dart';

void main() {
  group('ImmeublesModel', () {
    group('fromMap', () {
      test('parseia todos os campos obrigatórios', () {
        final map = {
          'id': 1,
          'name': 'Résidence Les Pins',
          'owner_id': 'uuid-owner',
          'is_active': true,
          'bail_location': false,
          'bail_individuel': false,
        };

        final model = ImmeublesModel.fromMap(map);

        expect(model.id, 1);
        expect(model.name, 'Résidence Les Pins');
        expect(model.ownerId, 'uuid-owner');
        expect(model.isActive, isTrue);
        expect(model.bailLocation, isFalse);
        expect(model.bailIndividuel, isFalse);
      });

      test('parseia campos opcionais', () {
        final map = {
          'id': 2,
          'name': 'Villa Rosa',
          'owner_id': 'uuid-owner',
          'type_id': 3,
          'address': '12 rue de la Paix',
          'city': 'Lyon',
          'region': 'Auvergne-Rhône-Alpes',
          'department': 'Rhône',
          'code_postal': '69001',
          'total_m2': 120.5,
          'description': 'Belle villa',
          'main_photo': 'https://example.com/photo.jpg',
          'prix_loyer': 1500.0,
          'location_meuble': true,
          'bail_location': true,
          'bail_individuel': false,
          'is_active': false,
          'created_at': '2024-01-15T10:30:00.000Z',
          'entreprise_id': 7,
          'common_photos': ['https://a.com/1.jpg', 'https://a.com/2.jpg'],
        };

        final model = ImmeublesModel.fromMap(map);

        expect(model.typeId, 3);
        expect(model.address, '12 rue de la Paix');
        expect(model.city, 'Lyon');
        expect(model.region, 'Auvergne-Rhône-Alpes');
        expect(model.department, 'Rhône');
        expect(model.codePostal, '69001');
        expect(model.totalM2, 120.5);
        expect(model.description, 'Belle villa');
        expect(model.mainPhoto, 'https://example.com/photo.jpg');
        expect(model.prixLoyer, 1500.0);
        expect(model.locationMeuble, isTrue);
        expect(model.bailLocation, isTrue);
        expect(model.isActive, isFalse);
        expect(model.createdAt, DateTime.parse('2024-01-15T10:30:00.000Z'));
        expect(model.entrepriseId, 7);
        expect(model.commonPhotos, hasLength(2));
      });

      test('parseia embed Immeuble_Types_Reference', () {
        final map = {
          'id': 3,
          'name': 'Studio Voltaire',
          'is_active': true,
          'bail_location': false,
          'bail_individuel': false,
          'Immeuble_Types_Reference': {'id': 2, 'name': 'Studio'},
        };

        final model = ImmeublesModel.fromMap(map);

        expect(model.type, isNotNull);
        expect(model.type, isA<ImmeubleTypeModel>());
        expect(model.type!.typeName, 'Studio');
      });

      test('type é null quando embed ausente', () {
        final map = {
          'id': 4,
          'name': 'Maison Blanche',
          'is_active': true,
          'bail_location': false,
          'bail_individuel': false,
        };

        final model = ImmeublesModel.fromMap(map);
        expect(model.type, isNull);
      });

      test('commonPhotos é lista vazia quando campo ausente', () {
        final map = {
          'id': 5,
          'name': 'Résidence A',
          'is_active': true,
          'bail_location': false,
          'bail_individuel': false,
        };

        final model = ImmeublesModel.fromMap(map);
        expect(model.commonPhotos, isEmpty);
      });

      test('commonPhotos é lista vazia quando campo é null', () {
        final map = {
          'id': 5,
          'name': 'Résidence A',
          'common_photos': null,
          'is_active': true,
          'bail_location': false,
          'bail_individuel': false,
        };

        final model = ImmeublesModel.fromMap(map);
        expect(model.commonPhotos, isEmpty);
      });

      test('aceita campo "nome" como alias de "name"', () {
        final map = {
          'id': 6,
          'nome': 'Imóvel Legado',
          'is_active': true,
          'bail_location': false,
          'bail_individuel': false,
        };

        final model = ImmeublesModel.fromMap(map);
        expect(model.name, 'Imóvel Legado');
      });

      test('campos numéricos são parseados de num', () {
        final map = {
          'id': 7,
          'name': 'Test',
          'total_m2': 85,
          'prix_loyer': 900,
          'entreprise_id': 3,
          'type_id': 1,
          'is_active': true,
          'bail_location': false,
          'bail_individuel': false,
        };

        final model = ImmeublesModel.fromMap(map);
        expect(model.totalM2, 85.0);
        expect(model.prixLoyer, 900.0);
        expect(model.entrepriseId, 3);
      });
    });

    group('bailLabel', () {
      test('retorna "Location" quando bailLocation=true', () {
        final model = ImmeublesModel(
          id: 1,
          name: 'Test',
          bailLocation: true,
        );
        expect(model.bailLabel, 'Location');
      });

      test('retorna "Bail individuel (Colocation)" quando bailIndividuel=true', () {
        final model = ImmeublesModel(
          id: 1,
          name: 'Test',
          bailIndividuel: true,
        );
        expect(model.bailLabel, 'Bail individuel (Colocation)');
      });

      test('retorna null quando nenhum bail selecionado', () {
        final model = ImmeublesModel(id: 1, name: 'Test');
        expect(model.bailLabel, isNull);
      });
    });

    group('nome getter', () {
      test('retorna o mesmo valor de name', () {
        final model = ImmeublesModel(id: 1, name: 'Résidence Belle Vue');
        expect(model.nome, model.name);
      });
    });

    group('toInsert', () {
      test('inclui campos obrigatórios', () {
        final model = ImmeublesModel(
          id: 1,
          name: 'Résidence Test',
          isActive: true,
          bailLocation: true,
          bailIndividuel: false,
        );

        final map = model.toInsert();

        expect(map['name'], 'Résidence Test');
        expect(map['is_active'], isTrue);
        expect(map['bail_location'], isTrue);
        expect(map['bail_individuel'], isFalse);
        expect(map.containsKey('common_photos'), isTrue);
      });

      test('omite campos null opcionais', () {
        final model = ImmeublesModel(id: 1, name: 'Test');
        final map = model.toInsert();

        expect(map.containsKey('owner_id'), isFalse);
        expect(map.containsKey('type_id'), isFalse);
        expect(map.containsKey('address'), isFalse);
        expect(map.containsKey('total_m2'), isFalse);
        expect(map.containsKey('prix_loyer'), isFalse);
        expect(map.containsKey('location_meuble'), isFalse);
        expect(map.containsKey('entreprise_id'), isFalse);
        expect(map.containsKey('code_postal'), isFalse);
      });

      test('inclui campos opcionais quando presentes', () {
        final model = ImmeublesModel(
          id: 1,
          name: 'Test',
          ownerId: 'uid',
          typeId: 2,
          address: '5 rue Test',
          city: 'Paris',
          region: 'Île-de-France',
          department: 'Seine',
          codePostal: '75001',
          totalM2: 80.0,
          description: 'Description',
          prixLoyer: 1200.0,
          locationMeuble: false,
          entrepriseId: 4,
        );

        final map = model.toInsert();

        expect(map['owner_id'], 'uid');
        expect(map['type_id'], 2);
        expect(map['address'], '5 rue Test');
        expect(map['city'], 'Paris');
        expect(map['region'], 'Île-de-France');
        expect(map['department'], 'Seine');
        expect(map['code_postal'], '75001');
        expect(map['total_m2'], 80.0);
        expect(map['description'], 'Description');
        expect(map['prix_loyer'], 1200.0);
        expect(map['location_meuble'], isFalse);
        expect(map['entreprise_id'], 4);
      });
    });
  });
}
