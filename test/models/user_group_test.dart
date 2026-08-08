import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/user_group.dart';

void main() {
  group('UserGroup', () {
    group('fromMap', () {
      test('parseia campos obrigatórios', () {
        final map = {
          'id': 1,
          'code': 'proprietaires',
          'name': 'Propriétaires',
        };

        final group = UserGroup.fromMap(map);

        expect(group.id, 1);
        expect(group.code, 'proprietaires');
        expect(group.name, 'Propriétaires');
        expect(group.permissionIds, isEmpty);
      });

      test('parseia campos opcionais', () {
        final map = {
          'id': 2,
          'code': 'locataires',
          'name': 'Locataires',
          'description': 'Groupe des locataires',
          'type_user_id': 1,
        };

        final group = UserGroup.fromMap(map);

        expect(group.description, 'Groupe des locataires');
        expect(group.typeUserId, 1);
      });

      test('parseia permissões do embed User_Group_Permissions', () {
        final map = {
          'id': 3,
          'code': 'super_admins',
          'name': 'Super Admins',
          'User_Group_Permissions': [
            {'permission_id': 10},
            {'permission_id': 11},
            {'permission_id': 15},
          ],
        };

        final group = UserGroup.fromMap(map);

        expect(group.permissionIds, {10, 11, 15});
      });

      test('permissões ficam vazio quando embed ausente', () {
        final map = {
          'id': 4,
          'code': 'admin_groupe',
          'name': 'Admin Groupe',
        };

        final group = UserGroup.fromMap(map);
        expect(group.permissionIds, isEmpty);
      });

      test('ignora entradas de permissão sem permission_id', () {
        final map = {
          'id': 5,
          'code': 'test',
          'name': 'Test',
          'User_Group_Permissions': [
            {'permission_id': 7},
            {'other_field': 'x'},
            {'permission_id': null},
          ],
        };

        final group = UserGroup.fromMap(map);
        expect(group.permissionIds, {7});
      });

      test('aceita permission_id como num (double)', () {
        final map = {
          'id': 6,
          'code': 'test',
          'name': 'Test',
          'User_Group_Permissions': [
            {'permission_id': 3.0},
          ],
        };

        final group = UserGroup.fromMap(map);
        expect(group.permissionIds, {3});
      });
    });

    group('copyWith', () {
      test('atualiza permissões mantendo outros campos', () {
        const original = UserGroup(
          id: 1,
          code: 'proprietaires',
          name: 'Propriétaires',
          description: 'Grupo principal',
          typeUserId: 2,
          permissionIds: {5, 6},
        );

        final updated = original.copyWith(permissionIds: {10, 11, 12});

        expect(updated.id, 1);
        expect(updated.code, 'proprietaires');
        expect(updated.name, 'Propriétaires');
        expect(updated.description, 'Grupo principal');
        expect(updated.typeUserId, 2);
        expect(updated.permissionIds, {10, 11, 12});
      });

      test('sem parâmetro preserva permissões originais', () {
        const original = UserGroup(
          id: 1,
          code: 'test',
          name: 'Test',
          permissionIds: {1, 2, 3},
        );

        final copy = original.copyWith();
        expect(copy.permissionIds, {1, 2, 3});
      });

      test('pode limpar permissões com conjunto vazio', () {
        const original = UserGroup(
          id: 1,
          code: 'test',
          name: 'Test',
          permissionIds: {5, 6, 7},
        );

        final updated = original.copyWith(permissionIds: {});
        expect(updated.permissionIds, isEmpty);
      });
    });
  });
}
