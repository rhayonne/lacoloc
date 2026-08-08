import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/chambre.dart';

void main() {
  group('ChambreModel', () {
    group('fromMap', () {
      test('parseia campos obrigatórios', () {
        final map = {
          'id': 10,
          'immeuble_id': 5,
          'room_name': 'Chambre 1',
          'is_active': true,
          'est_loue': false,
        };

        final model = ChambreModel.fromMap(map);

        expect(model.id, 10);
        expect(model.immeubleId, 5);
        expect(model.roomName, 'Chambre 1');
        expect(model.isActive, isTrue);
        expect(model.estLoue, isFalse);
        expect(model.roomPhotos, isEmpty);
        expect(model.selectedOptionIds, isEmpty);
      });

      test('parseia campos opcionais', () {
        final map = {
          'id': 11,
          'immeuble_id': 3,
          'room_name': 'Suite Deluxe',
          'm2': 22.5,
          'description': 'Grande chambre lumineuse',
          'prix_loyer': 650.0,
          'est_loue': true,
          'is_active': false,
          'main_photo': 'https://example.com/ph.jpg',
          'created_at': '2025-03-01T00:00:00.000Z',
          'room_photos': ['https://a.com/r1.jpg'],
          'selected_options': [1, 3, 5],
        };

        final model = ChambreModel.fromMap(map);

        expect(model.m2, 22.5);
        expect(model.description, 'Grande chambre lumineuse');
        expect(model.prixLoyer, 650.0);
        expect(model.estLoue, isTrue);
        expect(model.isActive, isFalse);
        expect(model.mainPhoto, 'https://example.com/ph.jpg');
        expect(model.createdAt, DateTime.parse('2025-03-01T00:00:00.000Z'));
        expect(model.roomPhotos, hasLength(1));
        expect(model.selectedOptionIds, [1, 3, 5]);
      });

      test('parseia embed Immeubles', () {
        final map = {
          'id': 12,
          'immeuble_id': 8,
          'room_name': 'Chambre 2',
          'is_active': true,
          'est_loue': false,
          'Immeubles': {
            'name': 'Villa Rosa',
            'address': '10 rue des Fleurs',
            'city': 'Marseille',
            'region': 'Provence',
            'department': 'Bouches-du-Rhône',
            'bail_location': true,
            'bail_individuel': false,
            'location_meuble': true,
            'type_id': 2,
          },
        };

        final model = ChambreModel.fromMap(map);

        expect(model.immeubleName, 'Villa Rosa');
        expect(model.immeubleAddress, '10 rue des Fleurs');
        expect(model.immeubleCity, 'Marseille');
        expect(model.immeubleRegion, 'Provence');
        expect(model.immeubleDepartment, 'Bouches-du-Rhône');
        expect(model.immeubleBailLocation, isTrue);
        expect(model.immeubleBailIndividuel, isFalse);
        expect(model.immeubleLocationMeuble, isTrue);
        expect(model.immeubleTypeId, 2);
      });

      test('campos do imóvel ficam null sem embed', () {
        final map = {
          'id': 13,
          'immeuble_id': 1,
          'room_name': 'Chambre A',
          'is_active': true,
          'est_loue': false,
        };

        final model = ChambreModel.fromMap(map);

        expect(model.immeubleName, isNull);
        expect(model.immeubleAddress, isNull);
        expect(model.immeubleCity, isNull);
        expect(model.immeubleBailLocation, isFalse);
        expect(model.immeubleBailIndividuel, isFalse);
        expect(model.immeubleLocationMeuble, isNull);
      });

      test('selectedOptionIds ignora zeros e strings não-numéricas', () {
        final map = {
          'id': 14,
          'immeuble_id': 1,
          'room_name': 'Chambre B',
          'is_active': true,
          'est_loue': false,
          'selected_options': [2, '4', 0, 'abc'],
        };

        final model = ChambreModel.fromMap(map);
        // 0 é ignorado; 'abc' → int.tryParse → 0 → ignorado; '4' → 4
        expect(model.selectedOptionIds, containsAll([2, 4]));
        expect(model.selectedOptionIds, isNot(contains(0)));
      });

      test('room_name vazio usa string vazia como fallback', () {
        final map = {
          'id': 15,
          'immeuble_id': 1,
          'is_active': true,
          'est_loue': false,
        };

        final model = ChambreModel.fromMap(map);
        expect(model.roomName, '');
      });
    });

    group('immeubleBailLabel', () {
      test('retorna "Location" quando immeubleBailLocation=true', () {
        final model = ChambreModel(
          id: 1,
          immeubleId: 1,
          roomName: 'C1',
          immeubleBailLocation: true,
        );
        expect(model.immeubleBailLabel, 'Location');
      });

      test('retorna "Bail individuel" quando immeubleBailIndividuel=true', () {
        final model = ChambreModel(
          id: 1,
          immeubleId: 1,
          roomName: 'C1',
          immeubleBailIndividuel: true,
        );
        expect(model.immeubleBailLabel, 'Bail individuel');
      });

      test('retorna null quando nenhum bail setado', () {
        final model = ChambreModel(id: 1, immeubleId: 1, roomName: 'C1');
        expect(model.immeubleBailLabel, isNull);
      });
    });

    group('toInsert', () {
      test('contém todos os campos obrigatórios', () {
        final model = ChambreModel(
          id: 1,
          immeubleId: 5,
          roomName: 'Chambre Test',
          isActive: true,
          estLoue: false,
        );

        final map = model.toInsert();

        expect(map['immeuble_id'], 5);
        expect(map['room_name'], 'Chambre Test');
        expect(map['room_photos'], isEmpty);
        expect(map['selected_options'], isEmpty);
        expect(map['is_active'], isTrue);
        expect(map['est_loue'], isFalse);
      });

      test('inclui campos opcionais quando presentes', () {
        final model = ChambreModel(
          id: 1,
          immeubleId: 3,
          roomName: 'Chambre Opt',
          m2: 18.0,
          description: 'Petite chambre',
          prixLoyer: 500.0,
          mainPhoto: 'https://img.com/x.jpg',
        );

        final map = model.toInsert();

        expect(map['m2'], 18.0);
        expect(map['description'], 'Petite chambre');
        expect(map['prix_loyer'], 500.0);
        expect(map['main_photo'], 'https://img.com/x.jpg');
      });

      test('omite campos null opcionais (m2, description, prix_loyer)', () {
        final model = ChambreModel(id: 1, immeubleId: 1, roomName: 'C');
        final map = model.toInsert();

        expect(map.containsKey('m2'), isFalse);
        expect(map.containsKey('description'), isFalse);
        expect(map.containsKey('prix_loyer'), isFalse);
        // main_photo é sempre incluído (pode ser null)
        expect(map.containsKey('main_photo'), isTrue);
      });
    });
  });
}
