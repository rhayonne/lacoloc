import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/utils/auth_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('authErrorMessage — doublon de téléphone', () {
    test('préfère le message du trigger, déjà rédigé en français', () {
      // Le trigger `users_client_phone_unique_locataire` lève ce texte : il est
      // plus précis que ce qu'on réécrirait (il dit « locataire »).
      final e = PostgrestException(
        message:
            'Ce numéro de téléphone est déjà utilisé par un autre compte locataire.',
        code: '23505',
      );

      expect(authErrorMessage(e),
          'Ce numéro de téléphone est déjà utilisé par un autre compte locataire.');
    });

    test('reconnaît la contrainte même sans message lisible', () {
      final e = PostgrestException(
        message: 'duplicate key value violates unique constraint '
            '"users_client_phone_unique_locataire"',
        code: '23505',
      );

      expect(authErrorMessage(e), contains('déjà utilisé'));
      expect(authErrorMessage(e), contains('locataire'));
      expect(authErrorMessage(e), isNot(contains('duplicate key')));
    });

    test('doublon d’e-mail reste distingué du téléphone', () {
      final e = PostgrestException(
        message: 'duplicate key value violates unique constraint '
            '"users_client_email_unique_ci"',
        code: '23505',
      );

      expect(authErrorMessage(e), 'Un compte existe déjà avec cet e-mail.');
    });

    test('doublon non identifié → message générique, jamais le SQL brut', () {
      final e = PostgrestException(
        message: 'duplicate key value violates unique constraint "autre_chose"',
        code: '23505',
      );

      expect(authErrorMessage(e), isNot(contains('duplicate key')));
      expect(authErrorMessage(e), contains('déjà utilisées'));
    });
  });

  group('authErrorMessage — inscription publique', () {
    test('l’erreur opaque de GoTrue devient une consigne actionnable', () {
      // GoTrue n'expose pas le détail Postgres quand un trigger refuse la
      // ligne : sans ce cas, l'utilisateur reste bloqué sans savoir pourquoi.
      final e = AuthException('Database error saving new user');

      final msg = authErrorMessage(e);
      expect(msg, contains('téléphone'));
      expect(msg, contains('Mon Profil'));
    });

    test('n’avale pas les erreurs d’authentification classiques', () {
      expect(
        authErrorMessage(AuthException('Invalid login credentials')),
        'E-mail ou mot de passe incorrect.',
      );
    });

    test('les erreurs réseau restent des erreurs réseau', () {
      expect(
        authErrorMessage(Exception('Failed to fetch')),
        contains('Connexion impossible'),
      );
    });
  });
}
