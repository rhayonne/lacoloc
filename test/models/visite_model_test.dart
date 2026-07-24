import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/models/visite.dart';

void main() {
  group('VisiteModel', () {
    group('fromMap', () {
      test('parseia todos os campos obrigatórios', () {
        final map = {
          'id': 1,
          'owner_id': 'uid-owner',
          'type_visite': 'visite_entree',
          'nom_visiteur': 'Jean Dupont',
          'date_visite': '2025-07-10T00:00:00.000Z',
          'created_at': '2025-06-01T00:00:00.000Z',
        };

        final v = VisiteModel.fromMap(map);

        expect(v.id, 1);
        expect(v.ownerId, 'uid-owner');
        expect(v.typeVisite, 'visite_entree');
        expect(v.nomVisiteur, 'Jean Dupont');
        expect(v.dateVisite, DateTime.parse('2025-07-10T00:00:00.000Z'));
        expect(v.createdAt, DateTime.parse('2025-06-01T00:00:00.000Z'));
        expect(v.telephone, isNull);
        expect(v.fournisseurId, isNull);
      });

      test('parseia campos opcionais', () {
        final map = {
          'id': 2,
          'owner_id': 'uid',
          'type_visite': 'reparation',
          'nom_visiteur': 'Plombier SA',
          'date_visite': '2025-08-15T00:00:00.000Z',
          'created_at': '2025-07-01T00:00:00.000Z',
          'telephone': '+33601020304',
          'fournisseur_id': 3,
        };

        final v = VisiteModel.fromMap(map);

        expect(v.telephone, '+33601020304');
        expect(v.fournisseurId, 3);
      });
    });

    group('toInsert', () {
      test('inclui campos obrigatórios', () {
        final v = VisiteModel(
          id: 1,
          ownerId: 'uid',
          typeVisite: 'visite_entree',
          nomVisiteur: 'Alice',
          dateVisite: DateTime(2025, 9, 1),
          createdAt: DateTime(2025, 8, 1),
        );

        final map = v.toInsert();

        expect(map['owner_id'], 'uid');
        expect(map['type_visite'], 'visite_entree');
        expect(map['nom_visiteur'], 'Alice');
        expect(map['date_visite'], '2025-09-01');
      });

      test('formata data_visite como YYYY-MM-DD', () {
        final v = VisiteModel(
          id: 1,
          ownerId: 'uid',
          typeVisite: 'reparation',
          nomVisiteur: 'Test',
          dateVisite: DateTime(2025, 12, 5),
          createdAt: DateTime.now(),
        );

        expect(v.toInsert()['date_visite'], '2025-12-05');
      });

      test('inclui telephone quando não vazio', () {
        final v = VisiteModel(
          id: 1,
          ownerId: 'uid',
          typeVisite: 'reparation',
          nomVisiteur: 'Test',
          telephone: '+33600000000',
          dateVisite: DateTime(2025, 1, 1),
          createdAt: DateTime.now(),
        );

        expect(v.toInsert()['telephone'], '+33600000000');
      });

      test('omite telephone null ou vazio', () {
        final v1 = VisiteModel(
          id: 1,
          ownerId: 'uid',
          typeVisite: 'reparation',
          nomVisiteur: 'Test',
          telephone: null,
          dateVisite: DateTime(2025, 1, 1),
          createdAt: DateTime.now(),
        );

        final v2 = VisiteModel(
          id: 2,
          ownerId: 'uid',
          typeVisite: 'reparation',
          nomVisiteur: 'Test',
          telephone: '',
          dateVisite: DateTime(2025, 1, 1),
          createdAt: DateTime.now(),
        );

        expect(v1.toInsert().containsKey('telephone'), isFalse);
        expect(v2.toInsert().containsKey('telephone'), isFalse);
      });

      test('inclui fournisseur_id quando presente', () {
        final v = VisiteModel(
          id: 1,
          ownerId: 'uid',
          typeVisite: 'reparation',
          nomVisiteur: 'Test',
          fournisseurId: 7,
          dateVisite: DateTime(2025, 1, 1),
          createdAt: DateTime.now(),
        );

        expect(v.toInsert()['fournisseur_id'], 7);
      });
    });

    group('copyWith', () {
      final original = VisiteModel(
        id: 1,
        ownerId: 'uid',
        typeVisite: 'visite_entree',
        nomVisiteur: 'Pierre',
        telephone: '+33600000001',
        fournisseurId: null,
        dateVisite: DateTime(2025, 6, 10),
        createdAt: DateTime(2025, 6, 1),
      );

      test('atualiza nomVisiteur mantendo outros campos', () {
        final updated = original.copyWith(nomVisiteur: 'Paul');
        expect(updated.nomVisiteur, 'Paul');
        expect(updated.ownerId, 'uid');
        expect(updated.typeVisite, 'visite_entree');
      });

      test('atualiza typeVisite', () {
        final updated = original.copyWith(typeVisite: 'reparation');
        expect(updated.typeVisite, 'reparation');
        expect(updated.nomVisiteur, 'Pierre');
      });

      test('atualiza fournisseurId', () {
        final updated = original.copyWith(fournisseurId: 5);
        expect(updated.fournisseurId, 5);
      });

      test('não altera original (imutabilidade)', () {
        original.copyWith(nomVisiteur: 'Outro');
        expect(original.nomVisiteur, 'Pierre');
      });
    });

    group('typeVisiteLabel', () {
      test('"etat_des_lieux_entree" → "État des lieux entrée"', () {
        expect(
          typeVisiteLabel('etat_des_lieux_entree'),
          'État des lieux entrée',
        );
      });

      test('"etat_des_lieux_sortie" → "État des lieux sortie"', () {
        expect(
          typeVisiteLabel('etat_des_lieux_sortie'),
          'État des lieux sortie',
        );
      });

      // Depuis la refonte « rendez-vous » (226b945), le libellé est « Visite ».
      test('"visite_entree" → "Visite"', () {
        expect(typeVisiteLabel('visite_entree'), 'Visite');
      });

      test('"reparation" → "Réparation"', () {
        expect(typeVisiteLabel('reparation'), 'Réparation');
      });

      test('tipo desconhecido → retorna o próprio tipo', () {
        expect(typeVisiteLabel('outro_tipo'), 'outro_tipo');
      });
    });

    group('kTypesVisite', () {
      // La refonte « rendez-vous » (226b945) a ajouté le type « autre ».
      test('contém os 5 tipos esperados', () {
        expect(kTypesVisite, contains('etat_des_lieux_entree'));
        expect(kTypesVisite, contains('etat_des_lieux_sortie'));
        expect(kTypesVisite, contains('visite_entree'));
        expect(kTypesVisite, contains('reparation'));
        expect(kTypesVisite, contains('autre'));
        expect(kTypesVisite, hasLength(5));
      });
    });

    group('typeVisiteColor', () {
      test('retorna uma Color para cada tipo', () {
        for (final type in kTypesVisite) {
          expect(typeVisiteColor(type), isA<Color>());
        }
      });

      test('tipo desconhecido retorna uma Color', () {
        expect(typeVisiteColor('desconhecido'), isA<Color>());
      });
    });
  });
}
