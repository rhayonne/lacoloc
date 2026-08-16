import 'package:flutter_test/flutter_test.dart';
import 'package:habitafrance/data/models/payment_methods.dart';

void main() {
  group('IBAN — normalisation', () {
    test('espaces et casse disparaissent', () {
      expect(
        PaymentMethods.normaliserIban('fr76 3000 1007 9412 3456 7890 185'),
        'FR7630001007941234567890185',
      );
    });

    test('la ponctuation d’un copier-coller est retirée', () {
      expect(
        PaymentMethods.normaliserIban('FR76-3000.1007/9412 3456 7890 185'),
        'FR7630001007941234567890185',
      );
    });
  });

  group('IBAN — contrôle mod 97', () {
    test('un IBAN français valide passe', () {
      expect(PaymentMethods.ibanValide('FR76 3000 1007 9412 3456 7890 185'),
          isTrue);
    });

    test('un chiffre modifié est détecté', () {
      // C'est tout l'intérêt : une faute de frappe envoie l'argent ailleurs.
      expect(PaymentMethods.ibanValide('FR76 3000 1007 9412 3456 7890 186'),
          isFalse);
    });

    test('deux chiffres intervertis sont détectés', () {
      expect(PaymentMethods.ibanValide('FR76 3000 1007 9412 3456 7809 185'),
          isFalse);
    });

    test('trop court, trop long, ou mal formé → refusé', () {
      expect(PaymentMethods.ibanValide('FR76'), isFalse);
      expect(PaymentMethods.ibanValide(''), isFalse);
      expect(PaymentMethods.ibanValide('7630001007941234567890185'), isFalse,
          reason: 'sans code pays');
      expect(PaymentMethods.ibanValide('FRXX3000100794123456789018'), isFalse,
          reason: 'clé non numérique');
    });

    test('un IBAN étranger valide passe aussi (le produit n’est pas franco-'
        'seulement)', () {
      expect(PaymentMethods.ibanValide('DE89 3704 0044 0532 0130 00'), isTrue);
      expect(PaymentMethods.ibanValide('BE71 0961 2345 6769'), isTrue);
    });
  });

  group('IBAN — affichage', () {
    test('groupé par 4 comme sur un RIB', () {
      expect(
        PaymentMethods.formaterIban('FR7630001007941234567890185'),
        'FR76 3000 1007 9412 3456 7890 185',
      );
    });
  });

  group('PaymentMethods', () {
    test('une fiche neuve est vide', () {
      expect(PaymentMethods.empty('u1').estVide, isTrue);
    });

    test('un champ rempli d’espaces ne compte pas comme renseigné', () {
      expect(PaymentMethods.empty('u1').copyWith(iban: '   ').estVide, isTrue);
    });

    test('toUpsert normalise les vides en null', () {
      final row = PaymentMethods.empty('u1')
          .copyWith(titulaireCompte: '  ', bic: '')
          .toUpsert();

      expect(row['titulaire_compte'], isNull);
      expect(row['bic'], isNull);
    });

    test('toUpsert stocke l’IBAN normalisé et le BIC en majuscules', () {
      final row = PaymentMethods.empty('u1')
          .copyWith(iban: 'fr76 3000 1007 9412 3456 7890 185', bic: 'bnpafrpp')
          .toUpsert();

      expect(row['iban'], 'FR7630001007941234567890185');
      expect(row['bic'], 'BNPAFRPP');
    });

    test('les interrupteurs Wero/PayPal sont toujours transmis', () {
      // Ce sont des booléens NOT NULL en base : les omettre casserait l'upsert.
      final row = PaymentMethods.empty('u1').toUpsert();
      expect(row.containsKey('wero_actif'), isTrue);
      expect(row.containsKey('paypal_actif'), isTrue);
    });

    test('fromMap tolère les booléens absents', () {
      final m = PaymentMethods.fromMap({'user_id': 'u1'});
      expect(m.weroActif, isFalse);
      expect(m.paypalActif, isFalse);
    });
  });
}
