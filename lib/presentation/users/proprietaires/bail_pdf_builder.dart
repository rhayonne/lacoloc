import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'bail_pdf_data.dart';

/// Génère un document PDF de bail conforme aux contrats-types obligatoires
/// (Décret n° 2015-587 du 29 mai 2015, loi 89-462 du 6 juillet 1989).
class BailPdfBuilder {
  final BailPdfData data;

  const BailPdfBuilder(this.data);

  Future<pw.Document> build() async {
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final fontItalic = await PdfGoogleFonts.notoSansItalic();

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

          // ══ VIII — ÉTAT DES LIEUX ═══════════════════════════════════════════
          section('VIII. État des lieux', [
            para(
              'Un état des lieux contradictoire sera établi, en autant d\'exemplaires qu\'il y a de parties, '
              'lors de la remise et de la restitution des clés, conformément aux articles 3-2 et 3-3 '
              'de la loi du 6 juillet 1989.',
            ),
            row("Date de l'état des lieux d'entrée", _dateStr(edl.dateEtatLieux)),
          ]),

          // ══ IX — CLAUSES DIVERSES ══════════════════════════════════════════
          section('IX. Clauses diverses', [
            para(
              'Toute modification au présent contrat devra faire l\'objet d\'un avenant '
              'écrit signé par les deux parties. '
              'En cas de litige, les parties s\'engagent à tenter une résolution amiable '
              'avant tout recours judiciaire.',
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
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Le bailleur', style: bold),
                    pw.SizedBox(height: 4),
                    pw.Text(d.bailleur.displayName, style: base),
                    pw.SizedBox(height: 32),
                    pw.Text('Signature :', style: base),
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(d.isColocation ? 'Le(s) colocataire(s)' : 'Le(s) locataire(s)', style: bold),
                    pw.SizedBox(height: 4),
                    if (d.preneurs.isNotEmpty)
                      pw.Text(d.preneurs.first.displayName, style: base),
                    pw.SizedBox(height: 32),
                    pw.Text('Signature :', style: base),
                    pw.Container(width: 150, height: 1, color: PdfColors.black),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Text('Fait à ${imm.city ?? '___________'}, le _______________', style: base),
            pw.SizedBox(height: 4),
            pw.Text('En deux exemplaires originaux.', style: italic),
          ]),

        ],
      ),
    );

    return doc;
  }

  // ── Helpers texte ──────────────────────────────────────────────────────────

  String _buildChargesDetail(BailPdfData d) {
    final parts = <String>[];

    final chargesRef = d.isColocation
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
}
