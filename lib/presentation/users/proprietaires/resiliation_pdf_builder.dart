import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/resiliation_pdf_data.dart';
import 'package:lacoloc_front/utils/currency.dart';

/// Génère le PDF court « Acte de résiliation et sortie de bail » : récapitule
/// le congé/préavis, l'état des lieux de sortie et l'acompte final de la
/// caution (déductions vétusté/litige, ou remboursement intégral).
Future<Uint8List> buildResiliationPdf(ResiliationPdfData data) async {
  final theme = pw.ThemeData.withFont(
    base: await PdfGoogleFonts.notoSansRegular(),
    bold: await PdfGoogleFonts.notoSansBold(),
  );
  final primary = PdfColor.fromHex('006685');
  final border =
      pw.TableBorder.all(color: PdfColor.fromHex('D1D5DB'), width: 0.4);
  final dateFmt = DateFormat('dd/MM/yyyy');
  final entree = data.entree;
  final sortie = data.sortie;

  pw.Widget label(String t) => pw.Text(t,
      style: pw.TextStyle(
          fontSize: 9,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700));
  pw.Widget value(String t) => pw.Text(t, style: const pw.TextStyle(fontSize: 10));
  pw.Widget cell(String t, {bool bold = false, PdfColor? color}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(t,
            style: pw.TextStyle(
                fontSize: 8,
                fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: color)),
      );

  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text('Acte de résiliation et sortie de bail',
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold, color: primary)),
        pw.SizedBox(height: 2),
        pw.Text('Bail ${entree.code ?? '#${entree.id}'} — ${entree.lieuLabel}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 14),

        // ── Parties ──────────────────────────────────────────────────────
        pw.Row(
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('BAILLEUR'),
                  value(entree.proprietaireNom ?? '—'),
                ],
              ),
            ),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  label('LOCATAIRE'),
                  value(entree.displayLocataire),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 14),

        // ── Récapitulatif du bail ────────────────────────────────────────
        label('RÉCAPITULATIF DU BAIL'),
        pw.SizedBox(height: 4),
        pw.Table(
          border: border,
          columnWidths: const {
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(3),
          },
          children: [
            if (entree.dateDebutBail != null)
              pw.TableRow(children: [
                cell('Date d\'entrée', bold: true),
                cell(dateFmt.format(entree.dateDebutBail!)),
              ]),
            if (entree.bailCongeDate != null)
              pw.TableRow(children: [
                cell('Date du congé', bold: true),
                cell(dateFmt.format(entree.bailCongeDate!)),
              ]),
            if (entree.preavisMois != null)
              pw.TableRow(children: [
                cell('Préavis', bold: true),
                cell('${entree.preavisMois} mois'),
              ]),
            if (entree.bailFinEffective != null)
              pw.TableRow(children: [
                cell('Fin effective du bail', bold: true),
                cell(dateFmt.format(entree.bailFinEffective!)),
              ]),
            if (entree.bailResilieMotif?.isNotEmpty == true)
              pw.TableRow(children: [
                cell('Motif', bold: true),
                cell(entree.bailResilieMotif!),
              ]),
          ],
        ),
        pw.SizedBox(height: 14),

        // ── État des lieux de sortie ─────────────────────────────────────
        label('ÉTAT DES LIEUX DE SORTIE'),
        pw.SizedBox(height: 4),
        if (sortie != null)
          pw.Text(
            'État des lieux ${sortie.code ?? '#${sortie.id}'} du '
            '${dateFmt.format(sortie.dateEtatLieux)}, accepté et signé par '
            'le locataire le '
            '${sortie.dateFinalisationFormatted ?? '—'}. Document annexé '
            'au présent acte.',
            style: const pw.TextStyle(fontSize: 9.5),
          )
        else
          pw.Text(
            "Aucun état des lieux de sortie retrouvé (document généré hors "
            "du parcours standard).",
            style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700),
          ),
        pw.SizedBox(height: 14),

        // ── Décompte final ───────────────────────────────────────────────
        label('DÉCOMPTE FINAL DE LA CAUTION'),
        pw.SizedBox(height: 4),
        pw.Table(
          border: border,
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('E0F2F8')),
              children: [cell('Poste', bold: true), cell('Montant', bold: true)],
            ),
            pw.TableRow(children: [
              cell('Caution reçue à l\'entrée'),
              cell(data.cautionMontant != null
                  ? formatEuros(data.cautionMontant!)
                  : '—'),
            ]),
            for (final d in data.vetusteDecomptes)
              pw.TableRow(children: [
                cell('Vétusté — ${d.titre ?? "décompte de sortie"}'),
                cell('− ${formatEuros(d.totalMontant)}'),
              ]),
            for (final f in data.factureLitiges)
              pw.TableRow(children: [
                cell('Litige — ${f.typeFacture} (${f.fournisseur})'),
                cell('− ${formatEuros(f.montantTtc)}'),
              ]),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text(
              data.sansLitige
                  ? 'Montant remboursé au locataire : '
                  : 'Montant net à rembourser au locataire : ',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              data.netARembourser != null
                  ? formatEuros(data.netARembourser!)
                  : '—',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: primary),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        if (!data.sansLitige)
          pw.Text(
            entree.isAvenant
                ? "Ce bail est un avenant (colocataire entré en cours de "
                    "contrat) : le règlement de la caution est traité "
                    "manuellement entre les parties."
                : "Des déductions (vétusté et/ou factures en litige) sont "
                    "imputées sur la caution — voir le détail ci-dessus.",
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          )
        else
          pw.Text(
            "Aucune dégradation ni litige constaté : la caution est "
            "intégralement restituée au locataire.",
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
        pw.SizedBox(height: 28),

        // ── Signatures ───────────────────────────────────────────────────
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Le bailleur', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 32),
                pw.Container(width: 160, height: 0.6, color: PdfColors.grey500),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Le locataire', style: const pw.TextStyle(fontSize: 9)),
                pw.SizedBox(height: 32),
                pw.Container(width: 160, height: 0.6, color: PdfColors.grey500),
              ],
            ),
          ],
        ),
      ],
    ),
  );
  return doc.save();
}

/// Page d'aperçu (impression / téléchargement) de l'acte de résiliation.
class ResiliationPdfPreviewPage extends StatelessWidget {
  final ResiliationPdfData data;
  const ResiliationPdfPreviewPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acte de résiliation')),
      body: PdfPreview(
        build: (_) => buildResiliationPdf(data),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
