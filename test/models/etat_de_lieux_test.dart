import 'package:flutter_test/flutter_test.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';

// Constrói um EtatDesLieuxModel mínimo válido.
EtatDesLieuxModel _minimal({
  int id = 1,
  String proprietaireId = 'uid-prop',
  int immeubleId = 10,
  String typeBail = 'collectif',
  String typeEdl = 'entree',
  DateTime? dateEtatLieux,
  SituationEdl situation = SituationEdl.enCours,
  PartieEdl partie = PartieEdl.commune,
  int? edlCollectifId,
  int? edlEntreeId,
  bool isAvenant = false,
  String? locataireNom,
  String? locataireEmail,
  List<String> preneursNoms = const [],
  String? immeubleNom,
  String? chambreNom,
  bool immeubleMeuble = false,
  String? immeubleTypeNom,
  bool locataireAccepte = false,
  DateTime? dateFinalisation,
}) =>
    EtatDesLieuxModel(
      id: id,
      proprietaireId: proprietaireId,
      immeubleId: immeubleId,
      typeBail: typeBail,
      typeEdl: typeEdl,
      dateEtatLieux: dateEtatLieux ?? DateTime(2025, 6, 10),
      situation: situation,
      createdAt: DateTime(2025, 6, 1),
      partie: partie,
      edlCollectifId: edlCollectifId,
      edlEntreeId: edlEntreeId,
      isAvenant: isAvenant,
      locataireNom: locataireNom,
      locataireEmail: locataireEmail,
      preneursNoms: preneursNoms,
      immeubleNom: immeubleNom,
      chambreNom: chambreNom,
      immeubleMeuble: immeubleMeuble,
      immeubleTypeNom: immeubleTypeNom,
      locataireAccepte: locataireAccepte,
      dateFinalisation: dateFinalisation,
    );

void main() {
  // ─── WallObservation ────────────────────────────────────────────────────────

  group('WallObservation', () {
    group('hasContent', () {
      test('true com description não vazia', () {
        const obs = WallObservation(description: 'Fissure', photos: []);
        expect(obs.hasContent, isTrue);
      });

      test('true com pelo menos uma foto', () {
        const obs = WallObservation(
            description: null, photos: ['https://img.com/a.jpg']);
        expect(obs.hasContent, isTrue);
      });

      test('false sem description e sem fotos', () {
        const obs = WallObservation(description: null, photos: []);
        expect(obs.hasContent, isFalse);
      });

      test('false com description vazia e sem fotos', () {
        const obs = WallObservation(description: '', photos: []);
        expect(obs.hasContent, isFalse);
      });
    });

    group('copyWith', () {
      test('atualiza description mantendo photos', () {
        const obs = WallObservation(
            description: 'Antes', photos: ['https://img.com/a.jpg']);
        final updated = obs.copyWith(description: 'Depois');
        expect(updated.description, 'Depois');
        expect(updated.photos, ['https://img.com/a.jpg']);
      });

      test('atualiza photos mantendo description', () {
        const obs = WallObservation(description: 'Desc', photos: []);
        final updated =
            obs.copyWith(photos: ['https://img.com/b.jpg', 'https://img.com/c.jpg']);
        expect(updated.description, 'Desc');
        expect(updated.photos, hasLength(2));
      });
    });

    group('toJson / fromJson', () {
      test('round-trip com description e fotos', () {
        const obs = WallObservation(
          description: 'Humidité détectée',
          photos: ['https://img.com/1.jpg'],
        );
        final json = obs.toJson();
        final restored = WallObservation.fromJson(json);

        expect(restored.description, 'Humidité détectée');
        expect(restored.photos, ['https://img.com/1.jpg']);
      });

      test('description null não aparece no json', () {
        const obs = WallObservation(description: null, photos: []);
        final json = obs.toJson();
        expect(json.containsKey('description'), isFalse);
        expect(json['photos'], isEmpty);
      });

      test('description vazia não aparece no json', () {
        const obs = WallObservation(description: '', photos: []);
        final json = obs.toJson();
        expect(json.containsKey('description'), isFalse);
      });

      test('fromJson com description null', () {
        final json = {'photos': <String>[]};
        final obs = WallObservation.fromJson(json);
        expect(obs.description, isNull);
        expect(obs.photos, isEmpty);
      });
    });
  });

  // ─── PartieEdl ──────────────────────────────────────────────────────────────

  group('PartieEdl', () {
    test('commune.raw → "commune"', () {
      expect(PartieEdl.commune.raw, 'commune');
    });

    test('privative.raw → "privative"', () {
      expect(PartieEdl.privative.raw, 'privative');
    });

    test('commune.label → "Parties communes"', () {
      expect(PartieEdl.commune.label, 'Parties communes');
    });

    test('privative.label → "Parties privatives"', () {
      expect(PartieEdl.privative.label, 'Parties privatives');
    });

    group('fromRaw', () {
      test('"commune" → commune', () {
        expect(PartieEdl.fromRaw('commune'), PartieEdl.commune);
      });

      test('"privative" → privative', () {
        expect(PartieEdl.fromRaw('privative'), PartieEdl.privative);
      });

      test('null → commune (default)', () {
        expect(PartieEdl.fromRaw(null), PartieEdl.commune);
      });

      test('valor desconhecido → commune (default)', () {
        expect(PartieEdl.fromRaw('invalido'), PartieEdl.commune);
      });
    });
  });

  // ─── SituationEdl ────────────────────────────────────────────────────────────

  group('SituationEdl', () {
    group('raw', () {
      test('enCours → "en_cours"', () {
        expect(SituationEdl.enCours.raw, 'en_cours');
      });

      test('aVenir → "a_venir"', () {
        expect(SituationEdl.aVenir.raw, 'a_venir');
      });

      test('finalise → "finalise"', () {
        expect(SituationEdl.finalise.raw, 'finalise');
      });
    });

    group('label', () {
      test('enCours → "En cours"', () {
        expect(SituationEdl.enCours.label, 'En cours');
      });

      test('aVenir → "À venir"', () {
        expect(SituationEdl.aVenir.label, 'À venir');
      });

      test('finalise → "Finalisé"', () {
        expect(SituationEdl.finalise.label, 'Finalisé');
      });
    });

    group('fromRaw', () {
      test('"a_venir" → aVenir', () {
        expect(SituationEdl.fromRaw('a_venir'), SituationEdl.aVenir);
      });

      test('"finalise" → finalise', () {
        expect(SituationEdl.fromRaw('finalise'), SituationEdl.finalise);
      });

      test('"en_cours" → enCours', () {
        expect(SituationEdl.fromRaw('en_cours'), SituationEdl.enCours);
      });

      test('null → enCours (default)', () {
        expect(SituationEdl.fromRaw(null), SituationEdl.enCours);
      });

      test('valor desconhecido → enCours (default)', () {
        expect(SituationEdl.fromRaw('xyz'), SituationEdl.enCours);
      });
    });

    group('fromDate', () {
      test('data futura → aVenir', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(SituationEdl.fromDate(tomorrow), SituationEdl.aVenir);
      });

      test('data passada → enCours', () {
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        expect(SituationEdl.fromDate(yesterday), SituationEdl.enCours);
      });

      test('hoje → enCours', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        expect(SituationEdl.fromDate(today), SituationEdl.enCours);
      });
    });
  });

  // ─── EtatDesLieuxModel ──────────────────────────────────────────────────────

  group('EtatDesLieuxModel', () {
    group('fromMap', () {
      test('parseia campos obrigatórios', () {
        final map = {
          'id': 42,
          'proprietaire_id': 'uid-prop',
          'immeuble_id': 10,
          'type_bail': 'individuel',
          'type_edl': 'entree',
          'date_etat_lieux': '2025-06-10',
          'situation': 'en_cours',
          'created_at': '2025-06-01T00:00:00.000Z',
        };

        final edl = EtatDesLieuxModel.fromMap(map);

        expect(edl.id, 42);
        expect(edl.proprietaireId, 'uid-prop');
        expect(edl.immeubleId, 10);
        expect(edl.typeBail, 'individuel');
        expect(edl.typeEdl, 'entree');
        expect(edl.dateEtatLieux, DateTime(2025, 6, 10));
        expect(edl.situation, SituationEdl.enCours);
        expect(edl.partie, PartieEdl.commune);
        expect(edl.isAvenant, isFalse);
        expect(edl.locataireAccepte, isFalse);
        expect(edl.observations, isEmpty);
      });

      test('parseia campos opcionais', () {
        final map = {
          'id': 1,
          'proprietaire_id': 'uid-prop',
          'immeuble_id': 5,
          'type_bail': 'collectif',
          'type_edl': 'sortie',
          'date_etat_lieux': '2025-01-01',
          'date_finalisation': '2025-02-01',
          'situation': 'finalise',
          'locataire_id': 'uid-loc',
          'chambre_id': 3,
          'montant': 800.0,
          'notes': 'RAS',
          'partie': 'privative',
          'edl_collectif_id': 9,
          'is_avenant': true,
          'avenant_date': '2025-03-01',
          'locataire_accepte': true,
          'created_at': '2025-01-01T00:00:00.000Z',
        };

        final edl = EtatDesLieuxModel.fromMap(map);

        expect(edl.typeEdl, 'sortie');
        expect(edl.dateFinalisation, DateTime(2025, 2, 1));
        expect(edl.situation, SituationEdl.finalise);
        expect(edl.locataireId, 'uid-loc');
        expect(edl.chambreId, 3);
        expect(edl.montant, 800.0);
        expect(edl.notes, 'RAS');
        expect(edl.partie, PartieEdl.privative);
        expect(edl.edlCollectifId, 9);
        expect(edl.isAvenant, isTrue);
        expect(edl.avenantDate, DateTime(2025, 3, 1));
        expect(edl.locataireAccepte, isTrue);
      });

      test('parseia observações JSONB', () {
        final map = {
          'id': 1,
          'proprietaire_id': 'uid',
          'immeuble_id': 1,
          'type_bail': 'collectif',
          'type_edl': 'entree',
          'date_etat_lieux': '2025-06-10',
          'situation': 'en_cours',
          'created_at': '2025-06-01T00:00:00.000Z',
          'observations': {
            'fond': {
              'description': 'Fissure',
              'photos': ['https://img.com/a.jpg']
            },
            'sol': {'description': null, 'photos': []},
          },
        };

        final edl = EtatDesLieuxModel.fromMap(map);

        expect(edl.observations, hasLength(2));
        expect(edl.observations['fond']!.description, 'Fissure');
        expect(edl.observations['fond']!.photos, hasLength(1));
        expect(edl.observations['sol']!.description, isNull);
      });

      test('parseia embeds de locataire, imóvel, chambre, proprietaire', () {
        final map = {
          'id': 1,
          'proprietaire_id': 'uid-prop',
          'immeuble_id': 1,
          'type_bail': 'individuel',
          'type_edl': 'entree',
          'date_etat_lieux': '2025-06-10',
          'situation': 'en_cours',
          'created_at': '2025-06-01T00:00:00.000Z',
          'locataire': {
            'full_name': 'Marie Curie',
            'email': 'marie@example.com',
            'phone': '+33612345678',
            'invitation_email_sent': true,
            'invitation_sent_at': '2025-05-01T00:00:00.000Z',
          },
          'immeuble': {
            'name': 'Résidence Albert',
            'address': '1 Place Einstein',
            'location_meuble': true,
            'type': {'name': 'Appartement'},
          },
          'chambre': {'room_name': 'Chambre 101'},
          'proprietaire': {'full_name': 'Pierre Dupont'},
        };

        final edl = EtatDesLieuxModel.fromMap(map);

        expect(edl.locataireNom, 'Marie Curie');
        expect(edl.locataireEmail, 'marie@example.com');
        expect(edl.locatairePhone, '+33612345678');
        expect(edl.locataireInvitationEmailSent, isTrue);
        expect(edl.locataireInvitationSentAt,
            DateTime.parse('2025-05-01T00:00:00.000Z'));
        expect(edl.immeubleNom, 'Résidence Albert');
        expect(edl.immeubleAdresse, '1 Place Einstein');
        expect(edl.immeubleMeuble, isTrue);
        expect(edl.immeubleTypeNom, 'Appartement');
        expect(edl.chambreNom, 'Chambre 101');
        expect(edl.proprietaireNom, 'Pierre Dupont');
      });

      test('parseia preneurs do embed', () {
        final map = {
          'id': 1,
          'proprietaire_id': 'uid-prop',
          'immeuble_id': 1,
          'type_bail': 'collectif',
          'type_edl': 'entree',
          'date_etat_lieux': '2025-06-10',
          'situation': 'en_cours',
          'created_at': '2025-06-01T00:00:00.000Z',
          'preneurs': [
            {
              'nom': 'Preneur Anonyme',
              'locataire': {'full_name': 'Alice Bernard'}
            },
            {'nom': 'Bob Martin', 'locataire': null},
            {'nom': '  ', 'locataire': null}, // nome vazio, deve ser ignorado
          ],
        };

        final edl = EtatDesLieuxModel.fromMap(map);

        expect(edl.preneursNoms, ['Alice Bernard', 'Bob Martin']);
        expect(edl.preneursNoms, hasLength(2));
      });
    });

    group('lieuLabel', () {
      test('retorna só imóvel quando sem chambre', () {
        final edl = _minimal(immeubleNom: 'Résidence Soleil');
        expect(edl.lieuLabel, 'Résidence Soleil');
      });

      test('usa "Immeuble" como fallback quando immeubleNom null', () {
        final edl = _minimal();
        expect(edl.lieuLabel, 'Immeuble');
      });

      test('concatena imóvel e chambre com " — "', () {
        final edl = _minimal(
          immeubleNom: 'Villa Rosa',
          chambreNom: 'Chambre 2',
        );
        expect(edl.lieuLabel, 'Villa Rosa — Chambre 2');
      });
    });

    group('displayLocataire', () {
      test('retorna locataireNom quando disponível', () {
        final edl = _minimal(locataireNom: 'Jean Moulin');
        expect(edl.displayLocataire, 'Jean Moulin');
      });

      test('retorna locataireEmail quando nome null', () {
        final edl = _minimal(locataireEmail: 'jean@example.com');
        expect(edl.displayLocataire, 'jean@example.com');
      });

      test('retorna preneurs concatenados quando sem locataire principal', () {
        final edl =
            _minimal(preneursNoms: ['Alice', 'Bob', 'Charlie']);
        expect(edl.displayLocataire, 'Alice, Bob, Charlie');
      });

      test('retorna "—" quando sem nenhuma informação', () {
        final edl = _minimal();
        expect(edl.displayLocataire, '—');
      });

      test('prioriza locataireNom sobre preneursNoms', () {
        final edl = _minimal(
          locataireNom: 'Principal',
          preneursNoms: ['Preneur A'],
        );
        expect(edl.displayLocataire, 'Principal');
      });
    });

    group('typeLabel e sensLabel', () {
      test('typeLabel → "Collectif" para partie commune (bail individuel)', () {
        final edl = _minimal(typeBail: 'individuel', partie: PartieEdl.commune);
        expect(edl.typeLabel, 'Collectif');
      });

      test('typeLabel → "Individuel" para partie privative', () {
        final edl = _minimal(partie: PartieEdl.privative);
        expect(edl.typeLabel, 'Individuel');
      });

      test('typeLabel → "Location" quando typeBail=location', () {
        final edl = _minimal(typeBail: 'location', partie: PartieEdl.commune);
        expect(edl.typeLabel, 'Location');
      });

      test('sensLabel → "Entrée" para typeEdl entree', () {
        final edl = _minimal(typeEdl: 'entree');
        expect(edl.sensLabel, 'Entrée');
      });

      test('sensLabel → "Sortie" para typeEdl sortie', () {
        final edl = _minimal(typeEdl: 'sortie');
        expect(edl.sensLabel, 'Sortie');
      });
    });

    group('isSortie', () {
      test('true quando typeEdl=sortie', () {
        expect(_minimal(typeEdl: 'sortie').isSortie, isTrue);
      });

      test('false quando typeEdl=entree', () {
        expect(_minimal(typeEdl: 'entree').isSortie, isFalse);
      });
    });

    group('edlEntreeId', () {
      test('toInsert inclui edl_entree_id quando presente', () {
        final edl = _minimal(edlEntreeId: 42);
        expect(edl.toInsert()['edl_entree_id'], 42);
      });

      test('toInsert omite edl_entree_id quando null', () {
        final edl = _minimal();
        expect(edl.toInsert().containsKey('edl_entree_id'), isFalse);
      });

      test('fromMap parseia edl_entree_id', () {
        final edl = EtatDesLieuxModel.fromMap({
          'id': 1,
          'proprietaire_id': 'uid',
          'immeuble_id': 10,
          'type_bail': 'individuel',
          'type_edl': 'sortie',
          'date_etat_lieux': '2026-06-05',
          'partie': 'privative',
          'edl_entree_id': 7,
        });
        expect(edl.edlEntreeId, 7);
      });
    });

    group('meubleLabel', () {
      test('"Meublée" quando immeubleMeuble=true', () {
        final edl = _minimal(immeubleMeuble: true);
        expect(edl.meubleLabel, 'Meublée');
      });

      test('"Non meublée" quando immeubleMeuble=false', () {
        final edl = _minimal(immeubleMeuble: false);
        expect(edl.meubleLabel, 'Non meublée');
      });
    });

    group('immeubleTypeLabel', () {
      test('retorna tipo do imóvel quando presente', () {
        final edl = _minimal(immeubleTypeNom: 'Maison');
        expect(edl.immeubleTypeLabel, 'Maison');
      });

      test('retorna "—" quando null', () {
        final edl = _minimal(immeubleTypeNom: null);
        expect(edl.immeubleTypeLabel, '—');
      });

      test('retorna "—" quando string vazia', () {
        final edl = _minimal(immeubleTypeNom: '');
        expect(edl.immeubleTypeLabel, '—');
      });
    });

    group('contratId', () {
      test('partie commune → retorna próprio id', () {
        final edl = _minimal(id: 55, partie: PartieEdl.commune);
        expect(edl.contratId, 55);
      });

      test('partie privative → retorna edlCollectifId', () {
        final edl = _minimal(
          id: 99,
          partie: PartieEdl.privative,
          edlCollectifId: 55,
        );
        expect(edl.contratId, 55);
      });

      test('partie privative sem edlCollectifId → null', () {
        final edl = _minimal(
          id: 99,
          partie: PartieEdl.privative,
          edlCollectifId: null,
        );
        expect(edl.contratId, isNull);
      });
    });

    group('dateEdlFormatted', () {
      test('formata data como dd/MM/yyyy', () {
        final edl = _minimal(dateEtatLieux: DateTime(2025, 6, 10));
        expect(edl.dateEdlFormatted, '10/06/2025');
      });
    });

    group('dateFinalisationFormatted', () {
      test('retorna null quando sem dateFinalisation', () {
        final edl = _minimal(dateFinalisation: null);
        expect(edl.dateFinalisationFormatted, isNull);
      });

      test('formata data de finalização', () {
        final edl = _minimal(dateFinalisation: DateTime(2025, 12, 31));
        expect(edl.dateFinalisationFormatted, '31/12/2025');
      });
    });

    group('toInsert', () {
      test('inclui campos obrigatórios', () {
        final edl = _minimal(
          id: 1,
          proprietaireId: 'uid-p',
          immeubleId: 7,
          typeBail: 'collectif',
          typeEdl: 'entree',
          dateEtatLieux: DateTime(2025, 6, 10),
          situation: SituationEdl.enCours,
          partie: PartieEdl.commune,
        );

        final map = edl.toInsert();

        expect(map['proprietaire_id'], 'uid-p');
        expect(map['immeuble_id'], 7);
        expect(map['type_bail'], 'collectif');
        expect(map['type_edl'], 'entree');
        expect(map['date_etat_lieux'], '2025-06-10');
        expect(map['situation'], 'en_cours');
        expect(map['partie'], 'commune');
        expect(map['is_avenant'], isFalse);
        expect(map['locataire_accepte'], isFalse);
      });

      test('omite campos null opcionais', () {
        final edl = _minimal();
        final map = edl.toInsert();

        expect(map.containsKey('locataire_id'), isFalse);
        expect(map.containsKey('chambre_id'), isFalse);
        expect(map.containsKey('montant'), isFalse);
        expect(map.containsKey('edl_collectif_id'), isFalse);
        expect(map.containsKey('notes'), isFalse);
      });
    });
  });
}
