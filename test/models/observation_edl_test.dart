import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/models/observation_edl.dart';

void main() {
  group('ObservationEdl', () {
    group('fromMap', () {
      test('parseia campos obrigatórios', () {
        final map = {
          'etat_de_lieux_id': 5,
          'photos': <String>[],
        };

        final obs = ObservationEdl.fromMap(map);

        expect(obs.etatDesLieuxId, 5);
        expect(obs.photos, isEmpty);
        expect(obs.isAddition, isFalse);
        expect(obs.wallKey, isNull);
        expect(obs.pieceId, isNull);
        expect(obs.chambreId, isNull);
        expect(obs.authorRole, isNull);
      });

      test('parseia campos opcionais', () {
        final map = {
          'id': 42,
          'etat_de_lieux_id': 7,
          'wall_key': 'fond',
          'piece_id': 3,
          'chambre_id': null,
          'description': 'Humidité au mur du fond',
          'photos': ['https://img.com/1.jpg', 'https://img.com/2.jpg'],
          'created_at': '2025-06-05T14:30:00.000Z',
          'author_role': 'locataire',
          'is_addition': true,
        };

        final obs = ObservationEdl.fromMap(map);

        expect(obs.id, 42);
        expect(obs.wallKey, 'fond');
        expect(obs.pieceId, 3);
        expect(obs.chambreId, isNull);
        expect(obs.description, 'Humidité au mur du fond');
        expect(obs.photos, hasLength(2));
        expect(obs.createdAt, DateTime.parse('2025-06-05T14:30:00.000Z'));
        expect(obs.authorRole, 'locataire');
        expect(obs.isAddition, isTrue);
      });
    });

    group('hasContent', () {
      test('true com description não vazia', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          description: 'Tache sur le plafond',
        );
        expect(obs.hasContent, isTrue);
      });

      test('true com pelo menos uma foto', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          photos: ['https://img.com/x.jpg'],
        );
        expect(obs.hasContent, isTrue);
      });

      test('false sem description nem fotos', () {
        const obs = ObservationEdl(etatDesLieuxId: 1);
        expect(obs.hasContent, isFalse);
      });

      test('false com description vazia e sem fotos', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, description: '');
        expect(obs.hasContent, isFalse);
      });
    });

    group('isLocataire', () {
      test('true quando authorRole = "locataire"', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          authorRole: 'locataire',
        );
        expect(obs.isLocataire, isTrue);
      });

      test('false quando authorRole = "proprietaire"', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          authorRole: 'proprietaire',
        );
        expect(obs.isLocataire, isFalse);
      });

      test('false quando authorRole null', () {
        const obs = ObservationEdl(etatDesLieuxId: 1);
        expect(obs.isLocataire, isFalse);
      });
    });

    group('wallLabel', () {
      test('"fond" → "Mur du fond"', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, wallKey: 'fond');
        expect(obs.wallLabel, 'Mur du fond');
      });

      test('"gauche" → "Mur gauche"', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, wallKey: 'gauche');
        expect(obs.wallLabel, 'Mur gauche');
      });

      test('"droit" → "Mur droit"', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, wallKey: 'droit');
        expect(obs.wallLabel, 'Mur droit');
      });

      test('"porte" → "Mur d\'entrée / Porte"', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, wallKey: 'porte');
        expect(obs.wallLabel, "Mur d'entrée / Porte");
      });

      test('"sol" → "Sol"', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, wallKey: 'sol');
        expect(obs.wallLabel, 'Sol');
      });

      test('"plafond" → "Plafond"', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, wallKey: 'plafond');
        expect(obs.wallLabel, 'Plafond');
      });

      test('null → "Général"', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, wallKey: null);
        expect(obs.wallLabel, 'Général');
      });

      test('valor desconhecido → "Général"', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, wallKey: 'outro');
        expect(obs.wallLabel, 'Général');
      });
    });

    group('toInsert', () {
      test('inclui campos obrigatórios', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 10,
          photos: [],
          isAddition: false,
        );

        final map = obs.toInsert();

        expect(map['etat_de_lieux_id'], 10);
        expect(map['photos'], isEmpty);
        expect(map['is_addition'], isFalse);
      });

      test('inclui wallKey quando presente', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          wallKey: 'sol',
          photos: [],
        );

        final map = obs.toInsert();
        expect(map['wall_key'], 'sol');
      });

      test('omite wallKey quando null', () {
        const obs = ObservationEdl(etatDesLieuxId: 1, photos: []);
        final map = obs.toInsert();
        expect(map.containsKey('wall_key'), isFalse);
      });

      test('inclui pieceId quando presente', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          pieceId: 5,
          photos: [],
        );
        expect(obs.toInsert()['piece_id'], 5);
      });

      test('omite description vazia', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          description: '',
          photos: [],
        );
        expect(obs.toInsert().containsKey('description'), isFalse);
      });

      test('inclui description quando não vazia', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          description: 'Fissure visible',
          photos: [],
        );
        expect(obs.toInsert()['description'], 'Fissure visible');
      });

      test('inclui authorRole quando presente', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          authorRole: 'locataire',
          photos: [],
        );
        expect(obs.toInsert()['author_role'], 'locataire');
      });

      test('is_addition=true para additions', () {
        const obs = ObservationEdl(
          etatDesLieuxId: 1,
          photos: [],
          isAddition: true,
        );
        expect(obs.toInsert()['is_addition'], isTrue);
      });
    });
  });
}
