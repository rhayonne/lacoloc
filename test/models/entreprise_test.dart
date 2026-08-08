import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/entreprise.dart';

void main() {
  group('Entreprise', () {
    group('fromMap', () {
      test('parseia todos os campos', () {
        final map = {
          'id': 1,
          'name': 'ImmoGest SAS',
          'domain': 'immogest.fr',
          'active': true,
          'created_at': '2024-03-15T09:00:00.000Z',
        };

        final emp = Entreprise.fromMap(map);

        expect(emp.id, 1);
        expect(emp.name, 'ImmoGest SAS');
        expect(emp.domain, 'immogest.fr');
        expect(emp.active, isTrue);
        expect(emp.createdAt, DateTime.parse('2024-03-15T09:00:00.000Z'));
      });

      test('domain pode ser null', () {
        final map = {
          'id': 2,
          'name': 'Gestion Habitat',
          'active': true,
        };

        final emp = Entreprise.fromMap(map);

        expect(emp.domain, isNull);
        expect(emp.createdAt, isNull);
      });

      test('active padrão é true quando ausente', () {
        final map = {
          'id': 3,
          'name': 'Société Test',
        };

        final emp = Entreprise.fromMap(map);
        expect(emp.active, isTrue);
      });

      test('active pode ser false', () {
        final map = {
          'id': 4,
          'name': 'Empresa Inativa',
          'active': false,
        };

        final emp = Entreprise.fromMap(map);
        expect(emp.active, isFalse);
      });

      test('id aceita num', () {
        final map = {
          'id': 5.0,
          'name': 'Empresa Num',
        };

        final emp = Entreprise.fromMap(map);
        expect(emp.id, 5);
      });
    });
  });
}
