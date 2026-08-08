import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/permission.dart';

void main() {
  group('PermissionRef', () {
    group('fromMap', () {
      test('parseia todos os campos', () {
        final map = {
          'id': 5,
          'key': 'immeubles.create',
          'label': 'Créer un immeuble',
          'description': 'Permet de créer de nouveaux immeubles',
          'category': 'immeubles',
        };

        final ref = PermissionRef.fromMap(map);

        expect(ref.id, 5);
        expect(ref.key, 'immeubles.create');
        expect(ref.label, 'Créer un immeuble');
        expect(ref.description, 'Permet de créer de nouveaux immeubles');
        expect(ref.category, 'immeubles');
      });

      test('description pode ser null', () {
        final map = {
          'id': 12,
          'key': 'edl.edit',
          'label': 'Modifier un EDL',
          'category': 'edl',
        };

        final ref = PermissionRef.fromMap(map);
        expect(ref.description, isNull);
        expect(ref.id, 12);
        expect(ref.key, 'edl.edit');
        expect(ref.category, 'edl');
      });
    });
  });

  group('UserPermission', () {
    group('fromMap', () {
      test('parseia todos os campos incluindo embed', () {
        final map = {
          'user_id': 'uid-abc',
          'permission_id': 7,
          'granted_at': '2025-01-15T10:00:00.000Z',
          'Permissions_Reference': {
            'id': 7,
            'key': 'factures.create',
            'label': 'Créer une facture',
            'description': null,
            'category': 'finances',
          },
        };

        final up = UserPermission.fromMap(map);

        expect(up.userId, 'uid-abc');
        expect(up.permissionId, 7);
        expect(up.grantedAt, DateTime.parse('2025-01-15T10:00:00.000Z'));
        expect(up.permission.key, 'factures.create');
        expect(up.permission.category, 'finances');
      });
    });
  });
}
