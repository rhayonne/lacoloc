import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/models/users_client.dart';

void main() {
  group('UserType', () {
    group('raw', () {
      test('locataire → "locataire"', () {
        expect(UserType.locataire.raw, 'locataire');
      });

      test('proprietaire → "proprietaire"', () {
        expect(UserType.proprietaire.raw, 'proprietaire');
      });

      test('adminGroupe → "admin_groupe"', () {
        expect(UserType.adminGroupe.raw, 'admin_groupe');
      });

      test('superAdmin → "super_admin"', () {
        expect(UserType.superAdmin.raw, 'super_admin');
      });
    });

    group('tryParse', () {
      test('parseia "locataire"', () {
        expect(UserType.tryParse('locataire'), UserType.locataire);
      });

      test('parseia "proprietaire"', () {
        expect(UserType.tryParse('proprietaire'), UserType.proprietaire);
      });

      test('parseia "admin_groupe"', () {
        expect(UserType.tryParse('admin_groupe'), UserType.adminGroupe);
      });

      test('parseia "super_admin"', () {
        expect(UserType.tryParse('super_admin'), UserType.superAdmin);
      });

      test('retorna null para valor desconhecido', () {
        expect(UserType.tryParse('desconhecido'), isNull);
      });

      test('retorna null para null', () {
        expect(UserType.tryParse(null), isNull);
      });

      test('tryParse é inverso de raw para todos os tipos', () {
        for (final type in UserType.values) {
          expect(UserType.tryParse(type.raw), type);
        }
      });
    });
  });

  group('UserTypeRef', () {
    group('fromMap', () {
      test('parseia todos os campos', () {
        final map = {
          'id': 2,
          'code': 'proprietaire',
          'label': 'Propriétaire',
          'description': 'Gère les imeubles',
        };

        final ref = UserTypeRef.fromMap(map);

        expect(ref.id, 2);
        expect(ref.code, 'proprietaire');
        expect(ref.label, 'Propriétaire');
        expect(ref.description, 'Gère les imeubles');
      });

      test('description pode ser null', () {
        final map = {
          'id': 1,
          'code': 'locataire',
          'label': 'Locataire',
        };

        final ref = UserTypeRef.fromMap(map);
        expect(ref.description, isNull);
      });
    });

    group('userType', () {
      test('resolve código válido para UserType', () {
        final ref = UserTypeRef.fromMap({
          'id': 3,
          'code': 'super_admin',
          'label': 'Super Admin',
        });
        expect(ref.userType, UserType.superAdmin);
      });

      test('retorna null para código desconhecido', () {
        final ref = UserTypeRef.fromMap({
          'id': 99,
          'code': 'unknown_type',
          'label': 'Inconnu',
        });
        expect(ref.userType, isNull);
      });
    });
  });

  group('UsersClient', () {
    group('fromJson', () {
      test('parseia campos obrigatórios', () {
        final json = {
          'id': 'uid-abc',
          'email': 'test@example.com',
          'created_at': '2024-06-01T00:00:00.000Z',
        };

        final client = UsersClient.fromJson(json);

        expect(client.id, 'uid-abc');
        expect(client.email, 'test@example.com');
        expect(client.active, isTrue);
      });

      test('parseia campos opcionais', () {
        final json = {
          'id': 'uid-xyz',
          'email': 'alice@example.com',
          'created_at': '2023-01-15T00:00:00.000Z',
          'full_name': 'Alice Dupont',
          'phone': '+33600000001',
          'age': 30,
          'date_of_birth': '1994-03-20',
          'type_user_id': 2,
          'active': false,
          'group_id': 4,
          'entreprise_id': 7,
        };

        final client = UsersClient.fromJson(json);

        expect(client.fullName, 'Alice Dupont');
        expect(client.phone, '+33600000001');
        expect(client.age, 30);
        expect(client.dateOfBirth, DateTime(1994, 3, 20));
        expect(client.typeUserId, 2);
        expect(client.active, isFalse);
        expect(client.groupId, 4);
        expect(client.entrepriseId, 7);
      });

      test('parseia embed User_Types_Reference', () {
        final json = {
          'id': 'uid-prop',
          'email': 'prop@example.com',
          'created_at': '2024-01-01T00:00:00.000Z',
          'User_Types_Reference': {
            'id': 2,
            'code': 'proprietaire',
            'label': 'Propriétaire',
          },
        };

        final client = UsersClient.fromJson(json);

        expect(client.typeUserRef, isNotNull);
        expect(client.typeUserRef!.code, 'proprietaire');
        expect(client.resolvedType, UserType.proprietaire);
      });

      test('resolvedType é null quando sem embed', () {
        final json = {
          'id': 'uid',
          'email': 'a@b.com',
          'created_at': '2024-01-01T00:00:00.000Z',
        };

        final client = UsersClient.fromJson(json);
        expect(client.typeUserRef, isNull);
        expect(client.resolvedType, isNull);
      });

      test('aceita campo "login" como alias de "email"', () {
        final json = {
          'id': 'uid',
          'login': 'login@example.com',
          'created_at': '2024-01-01T00:00:00.000Z',
        };

        final client = UsersClient.fromJson(json);
        expect(client.email, 'login@example.com');
      });

      test('group_id e entreprise_id aceitam num', () {
        final json = {
          'id': 'uid',
          'email': 'a@b.com',
          'created_at': '2024-01-01T00:00:00.000Z',
          'group_id': 2.0,
          'entreprise_id': 5.0,
        };

        final client = UsersClient.fromJson(json);
        expect(client.groupId, 2);
        expect(client.entrepriseId, 5);
      });
    });

    group('toJson', () {
      test('inclui campos obrigatórios', () {
        final client = UsersClient(
          id: 'uid-test',
          createdAt: DateTime(2024, 1, 1),
          email: 'user@test.com',
          active: true,
        );

        final json = client.toJson();

        expect(json['id'], 'uid-test');
        expect(json['email'], 'user@test.com');
        expect(json['active'], isTrue);
        expect(json.containsKey('created_at'), isTrue);
      });

      test('inclui full_name, phone e date_of_birth quando presentes', () {
        final client = UsersClient(
          id: 'uid',
          createdAt: DateTime(2024, 6, 10),
          email: 'x@x.com',
          fullName: 'Jean Martin',
          phone: '+33612345678',
          dateOfBirth: DateTime(1990, 5, 20),
        );

        final json = client.toJson();

        expect(json['full_name'], 'Jean Martin');
        expect(json['phone'], '+33612345678');
        expect(json['date_of_birth'], '1990-05-20');
      });

      test('omite campos null opcionais', () {
        final client = UsersClient(
          id: 'uid',
          createdAt: DateTime(2024, 1, 1),
          email: 'x@x.com',
        );

        final json = client.toJson();

        expect(json.containsKey('phone'), isFalse);
        expect(json.containsKey('age'), isFalse);
        expect(json.containsKey('date_of_birth'), isFalse);
        expect(json.containsKey('type_user_id'), isFalse);
      });
    });
  });
}
