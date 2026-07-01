import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:lacoloc_front/data/datasources/storage_service.dart';
import 'package:lacoloc_front/data/models/vetuste.dart';
import 'bail_pdf_data.dart';
import 'signature_proof.dart';

/// Génère un document PDF de bail conforme aux contrats-types obligatoires
/// (Décret n° 2015-587 du 29 mai 2015, loi 89-462 du 6 juillet 1989).
class BailPdfBuilder {
  final BailPdfData data;

  const BailPdfBuilder(this.data);

  Future<pw.Document> build({BailPdfScope scope = BailPdfScope.complet}) async {
    // Portée d'impression (miroir de l'EDL) : la section « Parties communes »
    // n'apparaît pas en portée « chambre » ; en portée « communes » on imprime
    // un extrait centré sur les parties communes.
    final showCommunes =
        scope != BailPdfScope.chambre && data.hasPartiesCommunes;
    final communesOnly = scope == BailPdfScope.communes;
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

    // Images de signature (best-effort : null si indisponible).
    final sigResults = await Future.wait([
      _fetchImageBytes(data.edl.proprietaireSignatureUrl),
      _fetchImageBytes(data.edl.locataireSignatureUrl),
    ]);
    final bailleurSig = sigResults[0];
    final preneurSig = sigResults[1];

    final doc = pw.Document();

    final base = pw.TextStyle(font: font, fontSize: 9);
    final bold = pw.TextStyle(font: fontBold, fontSize: 9);
    final italic = pw.TextStyle(font: fontItalic, fontSize: 9, color: PdfColors.grey700);
    final h1 = pw.TextStyle(font: fontBold, fontSize: 14);
    final h2 = pw.TextStyle(font: fontBold, fontSize: 11);
    final h3 = pw.TextStyle(font: fontBold, fontSize: 9.5);

    // ── Helpers ──────────────────────────────────────────────────────────────

    pw.Widget section(String title, List<pw.Widget> children) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              color: PdfColors.grey200,
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: pw.Text(title.toUpperCase(), style: h2),
            ),
            pw.SizedBox(height: 6),
            ...children,
          ],
        );

    pw.Widget article(String num, String title, List<pw.Widget> children) =>
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: 8),
            pw.Text('Article $num — $title', style: h3),
            pw.SizedBox(height: 4),
            ...children,
          ],
        );

    pw.Widget row(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 160,
                child: pw.Text('$label :', style: bold),
              ),
              pw.Expanded(child: pw.Text(value, style: base)),
            ],
          ),
        );

    pw.Widget para(String text) =>
        pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text(text, style: base));

    String fmt(double? v) => v != null ? '${v.toStringAsFixed(2)} €' : '—';
    String fmtI(int v) => v.toString();

    // ── Données ───────────────────────────────────────────────────────────────

    final d = data;
    final edl = d.edl;
    final imm = d.immeuble;
    final chambre = d.chambre;

    final dateEntree = _dateStr(edl.dateEtatLieux);
    final loyer = d.loyerHorsCharges;
    final charges = d.chargesFixesMensuelles;
    final loyerTotal = loyer != null ? loyer + charges : null;
    final depot = loyer != null ? loyer * d.depotGarantieMois : null;

    final prenomsList =
        d.preneurs.isNotEmpty ? d.preneurs.map((p) => p.displayName).join('\n') : '—';

    final chargesDetail = _buildChargesDetail(d);
    final meubleList = d.isMeuble ? _buildMeubleList(d) : '';

    // ── Document ──────────────────────────────────────────────────────────────

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(25, 25, 25, 25),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(d.titreBail, style: italic),
            pw.Text('Page ${ctx.pageNumber} / ${ctx.pagesCount}', style: italic),
          ],
        ),
        build: (ctx) => [

          // ══ EN-TÊTE ════════════════════════════════════════════════════════
          pw.Center(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text('CONTRAT DE LOCATION', style: h1),
                pw.SizedBox(height: 4),
                pw.Text(d.titreBail.toUpperCase(),
                    style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700)),
                pw.SizedBox(height: 4),
                pw.Text(d.texteLegal, style: italic, textAlign: pw.TextAlign.center),
              ],
            ),
          ),

          pw.SizedBox(height: 16),
          pw.Divider(),

          // ══ I — PARTIES ════════════════════════════════════════════════════
          section('I. Les parties', [
            pw.Text('LE BAILLEUR', style: h3),
            pw.SizedBox(height: 4),
            row('Nom et prénom', d.bailleur.displayName),
            if (d.bailleur.address != null) row('Adresse', d.bailleur.address!),
            if (d.bailleur.email != null) row('Email', d.bailleur.email!),
            if (d.bailleur.phone != null) row('Téléphone', d.bailleur.phone!),

            pw.SizedBox(height: 8),
            pw.Text(d.isColocation ? 'LE(S) PRENEUR(S) — COLOCATAIRE(S)' : 'LE(S) PRENEUR(S) — LOCATAIRE(S)',
                style: h3),
            pw.SizedBox(height: 4),
            for (final p in d.preneurs) ...[
              row('Nom et prénom', p.displayName),
              if (p.address != null) row('Adresse actuelle', p.address!),
              if (p.email != null) row('Email', p.email!),
              if (p.phone != null) row('Téléphone', p.phone!),
              pw.SizedBox(height: 4),
            ],
            if (d.preneurs.isEmpty) row('Preneur(s)', prenomsList),
          ]),

          // Sections II–IX : omises en portée « parties communes » (extrait).
          if (!communesOnly) ...[
          // ══ II — LE BIEN LOUÉ ═══════════════════════════════════════════════
          section('II. Le bien loué', [
            row('Type de bien', imm.type?.typeName ?? '—'),
            row('Adresse', d.adresseBien.isEmpty ? '—' : d.adresseBien),
            if (chambre != null) ...[
              row('Chambre', chambre.roomName),
              if (chambre.m2 != null) row('Surface privative', '${chambre.m2!.toStringAsFixed(1)} m²'),
            ] else if (imm.totalM2 != null)
              row('Surface totale', '${imm.totalM2!.toStringAsFixed(1)} m²'),
            if (imm.dpeClasse != null) row('Classe DPE', imm.dpeClasse!),
            if (d.isColocation) ...[
              pw.SizedBox(height: 4),
              para(
                'Le présent bail porte sur la chambre désignée ci-dessus. '
                'Le locataire a accès aux parties communes de l\'immeuble '
                'dans les conditions définies par le règlement intérieur.',
              ),
            ],
            if (d.isMeuble && meubleList.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text('Liste des équipements / mobilier :', style: bold),
              pw.SizedBox(height: 2),
              para(meubleList),
            ],
          ]),

          // ══ III — DURÉE DU BAIL ═════════════════════════════════════════════
          section('III. Durée du bail', [
            article('3.1', 'Prise d\'effet', [
              para('Le présent contrat prend effet à compter du $dateEntree.'),
            ]),
            article('3.2', 'Durée', [
              para(
                'La durée du bail est de ${fmtI(d.dureeMois)} mois'
                '${d.isMeuble ? ' (bail meublé renouvelable par tacite reconduction)' : ' (bail nu renouvelable par tacite reconduction)'}.',
              ),
              if (!d.isMeuble)
                para(
                  'Conformément à l\'article 10 de la loi du 6 juillet 1989, '
                  'le bail est renouvelé par tacite reconduction pour une durée de 3 ans.',
                ),
            ]),
          ]),

          // ══ IV — CONDITIONS FINANCIÈRES ════════════════════════════════════
          section('IV. Conditions financières', [
            article('4.1', 'Loyer', [
              row('Loyer mensuel hors charges', fmt(loyer)),
              if (charges > 0) row('Charges mensuelles forfaitaires', fmt(charges)),
              if (loyerTotal != null) row('Loyer total mensuel (HC+charges)', fmt(loyerTotal)),
              pw.SizedBox(height: 4),
              para(
                'Le loyer est payable mensuellement et d\'avance, le 1er de chaque mois. '
                'Tout retard de paiement pourra donner lieu à l\'application des pénalités '
                'légales prévues par la loi.',
              ),
            ]),
            if (imm.irlReference != null)
              article('4.2', 'Révision du loyer', [
                row('Indice de référence (IRL)', imm.irlReference!),
                para(
                  'Le loyer peut être révisé annuellement à la date anniversaire du bail, '
                  'en fonction de la variation de l\'Indice de Référence des Loyers (IRL) '
                  'publié par l\'INSEE, conformément à l\'article 17-1 de la loi du 6 juillet 1989.',
                ),
              ]),
            article('4.3', 'Charges', [
              if (chargesDetail.isNotEmpty)
                para(chargesDetail)
              else
                para('Aucune charge locative spécifique n\'est prévue au présent contrat.'),
            ]),
            article('4.4', 'Dépôt de garantie', [
              row('Montant du dépôt de garantie', fmt(depot)),
              para(
                'Le dépôt de garantie correspond à ${d.depotGarantieMois.toStringAsFixed(0)} mois de loyer hors charges, '
                'conformément à la réglementation en vigueur. '
                'Il sera restitué dans un délai maximal de 2 mois suivant la remise des clés, '
                'déduction faite des sommes restant dues au bailleur.',
              ),
            ]),
            if (d.garants.isNotEmpty)
              article('4.5', 'Cautionnement (garant)', [
                para(
                  'Le paiement des sommes dues au titre du présent bail est garanti '
                  'par le(s) cautionnement(s) suivant(s), dont les actes sont annexés '
                  'au présent contrat :',
                ),
                pw.SizedBox(height: 4),
                for (final g in d.garants) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    g.typeGarant == 'morale'
                        ? '${g.displayName} — ${g.typeGarantLabel}'
                        : g.displayName,
                    style: bold,
                  ),
                  row('Type de caution', g.typeCautionLabel),
                  if (g.typeGarant == 'morale') ...[
                    if (g.siret != null && g.siret!.isNotEmpty)
                      row('SIRET', g.siret!),
                    if (g.representantLegal != null &&
                        g.representantLegal!.isNotEmpty)
                      row('Représentant légal', g.representantLegal!),
                  ] else ...[
                    if (g.dateNaissanceFormatted != null)
                      row(
                        'Né(e) le',
                        '${g.dateNaissanceFormatted}'
                            '${g.lieuNaissance != null && g.lieuNaissance!.isNotEmpty ? ' à ${g.lieuNaissance}' : ''}',
                      ),
                    if (g.profession != null && g.profession!.isNotEmpty)
                      row('Profession', g.profession!),
                  ],
                  if ([g.adresse, g.codePostal, g.ville]
                      .any((s) => s != null && s.isNotEmpty))
                    row(
                      'Adresse',
                      [g.adresse, g.codePostal, g.ville]
                          .where((s) => s != null && s.isNotEmpty)
                          .join(', '),
                    ),
                  if (g.email != null && g.email!.isNotEmpty)
                    row('Email', g.email!),
                  if (g.telephone != null && g.telephone!.isNotEmpty)
                    row('Téléphone', g.telephone!),
                ],
              ]),
          ]),

          // ══ V — OBLIGATIONS DES PARTIES ════════════════════════════════════
          section('V. Obligations des parties', [
            article('5.1', 'Obligations du bailleur', [
              para(
                'Le bailleur s\'engage à :\n'
                '— Délivrer au locataire un logement décent et en bon état d\'usage et de réparation ;\n'
                '— Assurer au locataire la jouissance paisible du logement ;\n'
                '— Entretenir les locaux en état de servir à l\'usage prévu ;\n'
                '— Effectuer les réparations autres que locatives.',
              ),
            ]),
            article('5.2', 'Obligations du locataire', [
              para(
                'Le locataire s\'engage à :\n'
                '— Payer le loyer et les charges aux termes convenus ;\n'
                '— User paisiblement des locaux loués ;\n'
                '— Répondre des dégradations et pertes survenant pendant la durée du contrat ;\n'
                '— S\'assurer contre les risques locatifs (assurance habitation) ;\n'
                '— Laisser exécuter les travaux d\'amélioration décidés par le bailleur ;\n'
                '— Ne pas transformer les locaux sans accord écrit du bailleur.',
              ),
              para(
                'Justificatif d\'assurance : le locataire devra remettre au bailleur, '
                'lors de la remise des clés et à chaque renouvellement, '
                'une attestation d\'assurance en cours de validité.',
              ),
            ]),
          ]),

          // ══ VI — RÉSILIATION ════════════════════════════════════════════════
          section('VI. Résiliation du bail', [
            article('6.1', 'Congé donné par le locataire', [
              para(
                d.isMeuble
                    ? 'Le locataire peut résilier le bail à tout moment, avec un préavis d\'un (1) mois, '
                        'notifié par lettre recommandée avec avis de réception ou signification d\'huissier.'
                    : 'Le locataire peut résilier le bail à tout moment, avec un préavis de trois (3) mois, '
                        'notifié par lettre recommandée avec avis de réception ou signification d\'huissier. '
                        'Le délai peut être réduit à un (1) mois dans les zones tendues ou pour motif légitime.',
              ),
            ]),
            article('6.2', 'Congé donné par le bailleur', [
              para(
                'Le bailleur peut donner congé au locataire à l\'expiration du bail, '
                'pour reprise personnelle, vente du logement ou motif légitime et sérieux, '
                'avec un préavis de ${d.isMeuble ? 'trois (3)' : 'six (6)'} mois '
                'avant la date d\'échéance du contrat.',
              ),
            ]),
            article('6.3', 'Clause résolutoire', [
              para(
                'Le présent bail sera résilié de plein droit, à défaut de paiement '
                'du loyer ou des charges aux échéances convenues, du dépôt de garantie, '
                "ou en cas de défaut d'assurance des risques locatifs, deux (2) mois "
                'après un commandement de payer ou de justifier d\'une assurance demeuré '
                'infructueux (article 24 de la loi du 6 juillet 1989).',
              ),
            ]),
          ]),

          if (d.isColocation) ...[
            // ══ VII — CLAUSES COLOCATION ══════════════════════════════════════
            section('VII. Dispositions spécifiques à la colocation', [
              article('7.1', 'Solidarité des colocataires', [
                para(
                  'Chaque colocataire est responsable de sa quote-part de loyer et de charges. '
                  'En cas de bail individuel, le présent contrat ne crée pas de solidarité '
                  'entre les colocataires pour le paiement du loyer.',
                ),
              ]),
              article('7.2', 'Règlement intérieur', [
                para(
                  'Les colocataires s\'engagent à respecter les règles de vie commune '
                  'et à entretenir les parties communes dans le bon ordre et la propreté.',
                ),
              ]),
              article('7.3', 'Départ d\'un colocataire', [
                para(
                  'En cas de départ d\'un colocataire, le présent bail individuel prend fin '
                  'conformément aux dispositions de l\'article 6 ci-dessus. '
                  'Le bailleur peut conclure un nouveau bail avec un remplaçant.',
                ),
              ]),
            ]),
          ],

          // ══ VIII — ÉTAT DES LIEUX & VÉTUSTÉ ═════════════════════════════════
          section('VIII. État des lieux et vétusté', [
            para(
              'Un état des lieux contradictoire sera établi, en autant d\'exemplaires qu\'il y a de parties, '
              'lors de la remise et de la restitution des clés, conformément aux articles 3-2 et 3-3 '
              'de la loi du 6 juillet 1989.',
            ),
            row("Date de l'état des lieux d'entrée", _dateStr(edl.dateEtatLieux)),
            pw.SizedBox(height: 6),
            article('8.1', 'Définition de la vétusté', [
              para(
                "La vétusté s'entend de l'état d'usure ou de dégradation résultant "
                "du temps ou de l'usage normal des matériaux, équipements et "
                "meubles du logement, indépendamment de tout défaut d'entretien "
                "du locataire (article 1er du décret n° 2016-382 du 30 mars 2016).",
              ),
            ]),
            article('8.2', 'Répartition des réparations', [
              para(
                "Les réparations rendues nécessaires par la seule vétusté, ainsi "
                "que les réparations relevant de la responsabilité du bailleur, "
                "demeurent à sa charge. À l'inverse, les dégradations, pertes ou "
                "détériorations qui surviennent pendant la durée du bail et qui "
                "sont imputables au locataire — au-delà de l'usage normal — sont à "
                "sa charge (article 7 d) et e) de la loi du 6 juillet 1989), sauf "
                "lorsqu'elles résultent de la vétusté, d'un vice de construction, "
                "d'un cas de force majeure ou de la faute du bailleur.",
              ),
            ]),
            article('8.3', "Inventaire et état d'usure des biens", [
              para(
                "Le mobilier et les équipements faisant l'objet du présent bail sont "
                "décrits dans l'inventaire et l'état des lieux d'entrée, qui "
                "mentionnent pour chaque bien son état d'usure (neuf, bon état, "
                "état d'usage, mauvais état). Cet inventaire, établi et tenu à jour "
                "par le bailleur, fait foi entre les parties pour apprécier "
                "l'évolution de l'état des biens.",
              ),
            ]),
            article('8.4', 'Décompte de fin de bail', [
              para(
                "Au départ du locataire, l'état des lieux de sortie est comparé à "
                "l'état des lieux d'entrée. Seules les dégradations imputables au "
                "locataire peuvent donner lieu à retenue sur le dépôt de garantie. "
                "Le montant éventuellement dû par le locataire est calculé en tenant "
                "compte de la vétusté : la valeur d'un bien dégradé est diminuée en "
                "fonction de son ancienneté et de sa durée de vie théorique, selon la "
                "grille de vétusté ci-dessous. Aucune somme ne peut être réclamée au "
                "titre de l'usure normale.",
              ),
              pw.SizedBox(height: 4),
              para(
                "Mode de calcul : pour chaque bien, un abattement de vétusté est "
                "appliqué à sa valeur d'achat. "
                "Abattement (%) = (ancienneté en années − franchise) × coefficient "
                "annuel, plafonné de sorte qu'il reste toujours une valeur "
                "résiduelle minimale. "
                "Valeur résiduelle = valeur d'achat × (1 − abattement). Seule cette "
                "valeur résiduelle, le cas échéant, peut être mise à la charge du "
                "locataire pour un bien dégradé au-delà de l'usage normal.",
              ),
              if (d.baremeVetuste.isNotEmpty) ...[
                pw.SizedBox(height: 6),
                pw.Text('Grille de vétusté appliquée :', style: bold),
                pw.SizedBox(height: 3),
                _baremeTable(d.baremeVetuste, fontBold, font),
                pw.SizedBox(height: 3),
                pw.Text(
                  "Barème indicatif établi par le bailleur ; il ne fait pas "
                  "obstacle à l'appréciation amiable ou judiciaire de chaque "
                  "situation.",
                  style: pw.TextStyle(font: font, fontSize: 7.5, color: PdfColors.grey700),
                ),
              ],
            ]),
          ]),

          // ══ IX — DIAGNOSTICS, ANNEXES & CLAUSES DIVERSES ═══════════════════
          section('IX. Diagnostics, annexes et clauses diverses', [
            article('9.1', 'Dossier de diagnostics techniques (annexes)', [
              para(
                'Sont annexés au présent contrat et remis au locataire, conformément '
                "à l'article 3-3 de la loi du 6 juillet 1989 : le diagnostic de "
                "performance énergétique (DPE)${imm.dpeClasse != null ? ' — classe ${imm.dpeClasse}' : ''}, "
                "l'état des risques (naturels, miniers, technologiques, sismiques, "
                'radon), le constat de risque d\'exposition au plomb (logements '
                'construits avant 1949), ainsi que, le cas échéant, l\'état de '
                "l'installation intérieure d'électricité et de gaz et le diagnostic "
                'amiante. Une notice d\'information relative aux droits et obligations '
                'des parties est également annexée.',
              ),
            ]),
            article('9.2', 'Modifications et litiges', [
              para(
                'Toute modification au présent contrat devra faire l\'objet d\'un avenant '
                'écrit signé par les deux parties. '
                'En cas de litige, les parties s\'engagent à tenter une résolution amiable '
                '(le cas échéant devant la commission départementale de conciliation) '
                'avant tout recours judiciaire.',
              ),
            ]),
          ]),
          ], // fin du bloc « sections II–IX »

          // ══ PARTIES COMMUNES (miroir de l'EDL collectif) ════════════════════
          if (showCommunes)
            section('Parties communes (annexe collective)', [
              para(
                "Le présent bail individuel donne au preneur l'accès et la "
                "jouissance des parties communes de l'immeuble listées ci-dessous, "
                "dans les conditions définies par le règlement intérieur. Leur état "
                "est constaté dans l'état des lieux collectif (partie commune), "
                "annexé au présent contrat.",
              ),
              pw.SizedBox(height: 4),
              pw.Text('Pièces et espaces communs :', style: bold),
              pw.SizedBox(height: 2),
              para(d.piecesCommunes
                  .map((p) => p.nom)
                  .where((n) => n.trim().isNotEmpty)
                  .join(' · ')),
              pw.SizedBox(height: 4),
              para(
                "L'entretien courant des parties communes est assuré conformément "
                "au règlement intérieur ; les réparations dues à la vétusté restent "
                "à la charge du bailleur.",
              ),
            ]),

          // ══ X — SIGNATURES ═════════════════════════════════════════════════
          // NewPage : les signatures démarrent toujours sur une page dédiée
          // et ne sont jamais coupées entre deux pages.
          pw.NewPage(),
          section('X. Signatures', [
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _signatureBlock(
                  role: 'Le bailleur',
                  name: d.bailleur.displayName,
                  sigBytes: bailleurSig,
                  signedAt: d.edl.proprietaireSignedAtFormatted,
                  bold: bold,
                  base: base,
                ),
                _signatureBlock(
                  role: d.isColocation
                      ? 'Le(s) colocataire(s)'
                      : 'Le(s) locataire(s)',
                  name: d.preneurs.isNotEmpty ? d.preneurs.first.displayName : '',
                  sigBytes: preneurSig,
                  signedAt: d.edl.locataireSignedAtFormatted,
                  bold: bold,
                  base: base,
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text(
                'Fait à ${imm.city ?? '___________'}, le '
                '${d.edl.proprietaireSignedAtFormatted ?? '_______________'}',
                style: base),
            pw.SizedBox(height: 4),
            pw.Text('En deux exemplaires originaux.', style: italic),
            // Cachet de preuve de signature électronique (faisceau d'indices).
            buildSignatureProofBlock(
              base: base,
              bold: bold,
              signers: [
                ProofSigner(
                  role: 'Le bailleur',
                  name: d.bailleur.displayName,
                  email: d.bailleur.email,
                  signedAt: d.edl.proprietaireSignedAtFormatted,
                ),
                ProofSigner(
                  role: d.isColocation ? 'Le colocataire' : 'Le locataire',
                  name: d.preneurs.isNotEmpty
                      ? d.preneurs.first.displayName
                      : null,
                  email: d.preneurs.isNotEmpty ? d.preneurs.first.email : null,
                  signedAt: d.edl.locataireSignedAtFormatted,
                ),
              ],
              fingerprint: integrityFingerprint([
                'BAIL',
                d.edl.id,
                d.bailleur.displayName,
                d.bailleur.email,
                for (final p in d.preneurs) '${p.displayName}/${p.email}',
                d.adresseBien,
                loyer,
                charges,
                depot,
                dateEntree,
                d.edl.proprietaireSignatureUrl,
                d.edl.locataireSignatureUrl,
                d.edl.proprietaireSignedAtFormatted,
                d.edl.locataireSignedAtFormatted,
              ]),
            ),
          ]),

        ],
      ),
    );

    return doc;
  }

  // ── Helpers signature ───────────────────────────────────────────────────────

  /// Télécharge les bytes d'une image de signature (privée `doc:` ou URL
  /// publique). Retourne null si indisponible.
  Future<Uint8List?> _fetchImageBytes(String? ref) async {
    if (ref == null) return null;
    try {
      return await StorageService.downloadBytes(ref);
    } catch (_) {
      return null;
    }
  }

  /// Bloc de signature : rôle + nom + image de signature (ou ligne vierge).
  pw.Widget _signatureBlock({
    required String role,
    required String name,
    required Uint8List? sigBytes,
    required pw.TextStyle bold,
    required pw.TextStyle base,
    String? signedAt,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(role, style: bold),
        pw.SizedBox(height: 4),
        if (name.isNotEmpty) pw.Text(name, style: base),
        pw.SizedBox(height: 8),
        pw.Text(
          signedAt != null ? 'Signature (le $signedAt) :' : 'Signature :',
          style: base,
        ),
        pw.SizedBox(height: 4),
        if (sigBytes != null)
          pw.Container(
            width: 150,
            height: 48,
            alignment: pw.Alignment.centerLeft,
            child: pw.Image(
              pw.MemoryImage(sigBytes),
              fit: pw.BoxFit.contain,
              height: 48,
            ),
          )
        else
          pw.SizedBox(height: 24),
        pw.Container(width: 150, height: 1, color: PdfColors.black),
      ],
    );
  }

  // ── Helpers texte ──────────────────────────────────────────────────────────

  String _buildChargesDetail(BailPdfData d) {
    final parts = <String>[];

    final chargesRef = d.useChambreCharges
        ? [
            ...d.chambreChargesIncluses.map((c) => '${c.chargeRef?.nom ?? "Charge"} : incluse dans le loyer'),
            ...d.chambreChargesFixes.map((c) =>
                '${c.chargeRef?.nom ?? "Charge"} : ${c.montant?.toStringAsFixed(2) ?? "—"} €/mois'),
          ]
        : [
            ...d.chargesIncluses.map((c) => '${c.chargeRef?.nom ?? "Charge"} : incluse dans le loyer'),
            ...d.chargesFixesImmeuble.map((c) =>
                '${c.chargeRef?.nom ?? "Charge"} : ${c.montant?.toStringAsFixed(2) ?? "—"} €/mois'),
          ];

    if (chargesRef.isEmpty) return '';
    for (final item in chargesRef) {
      parts.add('— $item');
    }
    return 'Les charges locatives comprennent :\n${parts.join('\n')}';
  }

  String _buildMeubleList(BailPdfData d) {
    // On liste les équipements de la chambre si bail individuel
    // Le détail exhaustif est dans l'état des lieux — ici on donne un résumé.
    if (d.chambre?.selectedOptionIds.isNotEmpty == true) {
      return '(Voir inventaire joint à l\'état des lieux d\'entrée)';
    }
    return '(Voir inventaire joint à l\'état des lieux d\'entrée)';
  }

  static String _dateStr(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  /// Tableau de la grille de vétusté (article 8.4) : une ligne par catégorie.
  pw.Widget _baremeTable(
    List<VetusteBaremeModel> bareme,
    pw.Font fontBold,
    pw.Font font,
  ) {
    final headStyle = pw.TextStyle(font: fontBold, fontSize: 7.5);
    final cellStyle = pw.TextStyle(font: font, fontSize: 7.5);
    String pct(double v) => '${v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1)} %';

    pw.Widget cell(String t, {pw.TextStyle? style, pw.Alignment? align}) => pw.Container(
          alignment: align ?? pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: pw.Text(t, style: style ?? cellStyle),
        );

    final rows = <pw.TableRow>[
      pw.TableRow(
        decoration: const pw.BoxDecoration(color: PdfColors.grey200),
        children: [
          cell('Catégorie', style: headStyle),
          cell('Durée de vie', style: headStyle, align: pw.Alignment.center),
          cell('Franchise', style: headStyle, align: pw.Alignment.center),
          cell('Abattement / an', style: headStyle, align: pw.Alignment.center),
          cell('Valeur résiduelle min.', style: headStyle, align: pw.Alignment.center),
        ],
      ),
      for (final b in bareme)
        pw.TableRow(children: [
          cell(b.categorie),
          cell('${b.dureeVieAnnees} ans', align: pw.Alignment.center),
          cell('${b.franchiseAnnees} ans', align: pw.Alignment.center),
          cell(pct(b.coefficientAnnuel), align: pw.Alignment.center),
          cell(pct(b.residuelMinPct), align: pw.Alignment.center),
        ]),
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.2),
        1: pw.FlexColumnWidth(1.3),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FlexColumnWidth(1.5),
        4: pw.FlexColumnWidth(1.8),
      },
      children: rows,
    );
  }
}
