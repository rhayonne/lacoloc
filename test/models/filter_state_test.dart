import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/models/filter_state.dart';

void main() {
  group('ChambreFilter', () {
    group('isEmpty', () {
      test('true para filtro vazio padrão', () {
        expect(const ChambreFilter().isEmpty, isTrue);
      });

      test('true para ChambreFilter.empty', () {
        expect(ChambreFilter.empty.isEmpty, isTrue);
      });

      test('false quando city preenchida', () {
        expect(const ChambreFilter(city: 'Lyon').isEmpty, isFalse);
      });

      test('false quando region preenchida', () {
        expect(const ChambreFilter(region: 'Bretagne').isEmpty, isFalse);
      });

      test('false quando department preenchido', () {
        expect(const ChambreFilter(department: 'Rhône').isEmpty, isFalse);
      });

      test('false quando bailType definido', () {
        expect(
          const ChambreFilter(bailType: BailTypeFilter.collectif).isEmpty,
          isFalse,
        );
      });

      test('false quando meuble definido', () {
        expect(const ChambreFilter(meuble: true).isEmpty, isFalse);
      });

      test('false quando immeubleTypeId definido', () {
        expect(const ChambreFilter(immeubleTypeId: 3).isEmpty, isFalse);
      });

      test('false quando m2Min definido', () {
        expect(const ChambreFilter(m2Min: 15.0).isEmpty, isFalse);
      });

      test('false quando m2Max definido', () {
        expect(const ChambreFilter(m2Max: 30.0).isEmpty, isFalse);
      });

      test('false quando prixMin definido', () {
        expect(const ChambreFilter(prixMin: 400.0).isEmpty, isFalse);
      });

      test('false quando prixMax definido', () {
        expect(const ChambreFilter(prixMax: 900.0).isEmpty, isFalse);
      });

      test('false quando equipements não vazio', () {
        expect(const ChambreFilter(equipements: {'Wifi', 'Douche'}).isEmpty, isFalse);
      });
    });

    group('activeCount', () {
      test('0 para filtro vazio', () {
        expect(const ChambreFilter().activeCount, 0);
      });

      test('conta cada campo preenchido como 1', () {
        const filter = ChambreFilter(
          city: 'Paris',
          region: 'Île-de-France',
          department: 'Seine',
          bailType: BailTypeFilter.individuel,
          meuble: false,
          immeubleTypeId: 1,
          equipements: {'Wifi', 'Douche'},
        );
        // 7 campos individuais = 7
        expect(filter.activeCount, 7);
      });

      test('m2Min e m2Max contam como 1 juntos', () {
        const f1 = ChambreFilter(m2Min: 10.0);
        const f2 = ChambreFilter(m2Max: 50.0);
        const f3 = ChambreFilter(m2Min: 10.0, m2Max: 50.0);

        expect(f1.activeCount, 1);
        expect(f2.activeCount, 1);
        expect(f3.activeCount, 1);
      });

      test('prixMin e prixMax contam como 1 juntos', () {
        const f1 = ChambreFilter(prixMin: 300.0);
        const f2 = ChambreFilter(prixMax: 800.0);
        const f3 = ChambreFilter(prixMin: 300.0, prixMax: 800.0);

        expect(f1.activeCount, 1);
        expect(f2.activeCount, 1);
        expect(f3.activeCount, 1);
      });

      test('máximo possível: todos os filtros ativos', () {
        const filter = ChambreFilter(
          city: 'Bordeaux',
          region: 'Nouvelle-Aquitaine',
          department: 'Gironde',
          bailType: BailTypeFilter.collectif,
          meuble: true,
          immeubleTypeId: 2,
          equipements: {'Wifi'},
          m2Min: 10.0,
          m2Max: 40.0,
          prixMin: 200.0,
          prixMax: 700.0,
        );
        expect(filter.activeCount, 9);
      });
    });

    group('copyWith', () {
      test('atualiza city mantendo outros campos', () {
        const original = ChambreFilter(
          city: 'Marseille',
          bailType: BailTypeFilter.individuel,
        );

        final updated = original.copyWith(city: 'Toulouse');

        expect(updated.city, 'Toulouse');
        expect(updated.bailType, BailTypeFilter.individuel);
      });

      test('limpa bailType passando null explicitamente', () {
        const original =
            ChambreFilter(bailType: BailTypeFilter.collectif);

        final updated = original.copyWith(bailType: null);

        expect(updated.bailType, isNull);
      });

      test('preserva bailType quando não especificado', () {
        const original =
            ChambreFilter(bailType: BailTypeFilter.individuel);

        final updated = original.copyWith(city: 'Nice');

        expect(updated.bailType, BailTypeFilter.individuel);
      });

      test('limpa meuble passando null', () {
        const original = ChambreFilter(meuble: true);
        final updated = original.copyWith(meuble: null);
        expect(updated.meuble, isNull);
      });

      test('preserva meuble quando não especificado', () {
        const original = ChambreFilter(meuble: false);
        final updated = original.copyWith(city: 'Nantes');
        expect(updated.meuble, isFalse);
      });

      test('limpa imeubleTypeId passando null', () {
        const original = ChambreFilter(immeubleTypeId: 5);
        final updated = original.copyWith(immeubleTypeId: null);
        expect(updated.immeubleTypeId, isNull);
      });

      test('limpa m2Min/m2Max passando null', () {
        const original = ChambreFilter(m2Min: 10.0, m2Max: 60.0);

        final cleared = original.copyWith(m2Min: null, m2Max: null);

        expect(cleared.m2Min, isNull);
        expect(cleared.m2Max, isNull);
      });

      test('limpa prixMin/prixMax passando null', () {
        const original = ChambreFilter(prixMin: 300.0, prixMax: 900.0);

        final cleared = original.copyWith(prixMin: null, prixMax: null);

        expect(cleared.prixMin, isNull);
        expect(cleared.prixMax, isNull);
      });

      test('atualiza equipements', () {
        const original = ChambreFilter(equipements: {'Wifi', 'Douche'});
        final updated = original.copyWith(equipements: {'Balcon', 'Fenêtre'});
        expect(updated.equipements, {'Balcon', 'Fenêtre'});
      });

      test('não altera original (imutabilidade)', () {
        const original = ChambreFilter(city: 'Rennes', prixMin: 400.0);
        original.copyWith(city: 'Brest', prixMin: 500.0);

        expect(original.city, 'Rennes');
        expect(original.prixMin, 400.0);
      });
    });

    group('BailTypeFilter', () {
      test('enum tem collectif e individuel', () {
        expect(BailTypeFilter.values, contains(BailTypeFilter.collectif));
        expect(BailTypeFilter.values, contains(BailTypeFilter.individuel));
        expect(BailTypeFilter.values, hasLength(2));
      });
    });
  });
}
