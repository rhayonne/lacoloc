import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/profile_visibility.dart';

void main() {
  group('ProfileVisibility — défauts asymétriques (RGPD)', () {
    test('locataire : tout visible (consenti au moment du contact)', () {
      const v = ProfileVisibility.consentiDefaults;
      for (final f in ProfileVisibilityField.values) {
        expect(v.isVisible(f), isTrue, reason: f.key);
      }
    });

    test('bailleur : aucune coordonnée par défaut (minimisation)', () {
      const v = ProfileVisibility.minimalDefaults;
      for (final f in ProfileVisibilityField.values) {
        expect(v.isVisible(f), isFalse, reason: f.key);
      }
    });

    test('defaultsFor : locataire → consenti, tout le reste → minimal', () {
      expect(ProfileVisibility.defaultsFor(isLocataire: true),
          ProfileVisibility.consentiDefaults);
      expect(ProfileVisibility.defaultsFor(isLocataire: false),
          ProfileVisibility.minimalDefaults);
    });

    test('un champ non renseigné suit le défaut du RÔLE, pas un défaut global',
        () {
      // Même JSON vide, deux résultats : c'est tout l'enjeu de l'asymétrie.
      expect(
        ProfileVisibility.fromJson(const {},
                fallback: ProfileVisibility.minimalDefaults)
            .isVisible(ProfileVisibilityField.phone),
        isFalse,
      );
      expect(
        ProfileVisibility.fromJson(const {},
                fallback: ProfileVisibility.consentiDefaults)
            .isVisible(ProfileVisibilityField.phone),
        isTrue,
      );
    });

    test('un choix explicite l’emporte toujours sur le défaut du rôle', () {
      final v = ProfileVisibility.fromJson({'phone': true, 'email': true},
          fallback: ProfileVisibility.minimalDefaults);
      expect(v.isVisible(ProfileVisibilityField.phone), isTrue);
      expect(v.isVisible(ProfileVisibilityField.email), isTrue);
      expect(v.isVisible(ProfileVisibilityField.age), isFalse);
    });
  });

  group('ProfileVisibility', () {
    test('colonne absente / null → défaut fourni', () {
      expect(ProfileVisibility.fromJson(null), ProfileVisibility.defaults);
      expect(
        ProfileVisibility.fromJson(const <String, dynamic>{}),
        ProfileVisibility.defaults,
      );
    });

    test('lit les clés présentes et garde le défaut pour les absentes', () {
      final v = ProfileVisibility.fromJson({'phone': false});
      expect(v.isVisible(ProfileVisibilityField.phone), isFalse);
      expect(v.isVisible(ProfileVisibilityField.email), isTrue);
      expect(v.isVisible(ProfileVisibilityField.age), isTrue);
    });

    test('valeur non booléenne → défaut du champ (jamais une exception)', () {
      final v = ProfileVisibility.fromJson({'email': 'non'});
      expect(v.isVisible(ProfileVisibilityField.email), isTrue);
    });

    test('toJson écrit toutes les clés', () {
      final json = ProfileVisibility.fromJson({'age': false}).toJson();
      expect(json, {'age': false, 'phone': true, 'email': true});
    });

    test('withField ne touche qu’un seul champ', () {
      final v = ProfileVisibility.defaults
          .withField(ProfileVisibilityField.age, false);
      expect(v.isVisible(ProfileVisibilityField.age), isFalse);
      expect(v.isVisible(ProfileVisibilityField.phone), isTrue);
      expect(v.isVisible(ProfileVisibilityField.email), isTrue);
    });

    test('égalité par valeur (évite les rebuilds inutiles)', () {
      expect(
        ProfileVisibility.fromJson({'phone': false}),
        ProfileVisibility.fromJson({'phone': false, 'email': true}),
      );
      expect(
        ProfileVisibility.fromJson({'phone': false}),
        isNot(ProfileVisibility.defaults),
      );
    });

    test('les clés correspondent aux libellés de champ attendus', () {
      expect(ProfileVisibilityField.values.map((f) => f.key).toList(),
          ['age', 'phone', 'email']);
    });
  });
}
