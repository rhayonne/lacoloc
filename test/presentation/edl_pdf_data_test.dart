import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/models/edl_details.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/data/models/observation_edl.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/edl_pdf_data.dart';

// EDL privatif minimal (bail individuel).
EtatDesLieuxModel _edl() => EtatDesLieuxModel(
      id: 200,
      proprietaireId: 'uid',
      immeubleId: 10,
      typeBail: 'individuel',
      typeEdl: 'entree',
      dateEtatLieux: DateTime(2026, 6, 5),
      situation: SituationEdl.enCours,
      createdAt: DateTime(2026, 6, 1),
      partie: PartieEdl.privative,
    );

const _collectifId = 100;
const _privatifId = 200;

EdlPdfData _individuel() => EdlPdfData(
      edl: _edl(),
      preneurs: const [EdlPreneur(etatDesLieuxId: _collectifId, nom: 'Jean')],
      releves: const [
        EdlReleve(etatDesLieuxId: _collectifId, categorie: ReleveCategorie.eauGaz),
      ],
      cles: const [EdlCle(etatDesLieuxId: _privatifId, typeCle: 'Porte')],
      sections: const [
        EdlSection(etatDesLieuxId: _collectifId, nom: 'CUISINE'),
        EdlSection(etatDesLieuxId: _privatifId, nom: 'CHAMBRE'),
      ],
      observations: const [
        ObservationEdl(etatDesLieuxId: _collectifId, description: 'commune'),
        ObservationEdl(etatDesLieuxId: _privatifId, description: 'chambre'),
      ],
      additions: const [
        ObservationEdl(
          etatDesLieuxId: _privatifId,
          description: 'addition',
          isAddition: true,
        ),
      ],
      collectifEdlId: _collectifId,
      privatifEdlId: _privatifId,
    );

void main() {
  group('EdlPdfData', () {
    test('isIndividuel: true avec collectif+privatif', () {
      expect(_individuel().isIndividuel, isTrue);
    });

    test('isIndividuel: false sans privatif (collectif seul)', () {
      final data = EdlPdfData(
        edl: _edl(),
        preneurs: const [],
        releves: const [],
        cles: const [],
        sections: const [],
        observations: const [],
        additions: const [],
        collectifEdlId: _collectifId,
      );
      expect(data.isIndividuel, isFalse);
    });

    group('scoped', () {
      test('complet → identique', () {
        final d = _individuel().scoped(EdlPdfScope.complet);
        expect(d.sections, hasLength(2));
        expect(d.observations, hasLength(2));
        expect(d.cles, hasLength(1));
        expect(d.releves, hasLength(1));
      });

      test('communes → seulement le collectif (relevés gardés, clés vides)', () {
        final d = _individuel().scoped(EdlPdfScope.communes);
        expect(d.sections, hasLength(1));
        expect(d.sections.single.etatDesLieuxId, _collectifId);
        expect(d.observations.single.etatDesLieuxId, _collectifId);
        expect(d.releves, hasLength(1));
        expect(d.cles, isEmpty);
        expect(d.additions, isEmpty);
      });

      test('chambre → seulement le privatif (clés gardées, relevés vides)', () {
        final d = _individuel().scoped(EdlPdfScope.chambre);
        expect(d.sections, hasLength(1));
        expect(d.sections.single.etatDesLieuxId, _privatifId);
        expect(d.observations.single.etatDesLieuxId, _privatifId);
        expect(d.cles, hasLength(1));
        expect(d.releves, isEmpty);
        expect(d.additions, hasLength(1));
      });

      test('non-individuel → scoped ne filtre pas', () {
        final data = EdlPdfData(
          edl: _edl(),
          preneurs: const [],
          releves: const [],
          cles: const [],
          sections: const [EdlSection(etatDesLieuxId: _collectifId, nom: 'X')],
          observations: const [],
          additions: const [],
          collectifEdlId: _collectifId,
        );
        final d = data.scoped(EdlPdfScope.chambre);
        expect(d.sections, hasLength(1));
      });
    });
  });
}
