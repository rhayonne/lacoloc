import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:lacoloc_front/data/models/vetuste.dart';
import 'package:lacoloc_front/utils/currency.dart';

/// Génère le PDF « Décompte de réparations locatives » d'un décompte de vétusté.
Future<Uint8List> buildVetustePdf(
  VetusteDecompteModel header,
  List<VetusteDecompteLigneModel> lignes,
) async {
  final theme = pw.ThemeData.withFont(
    base: await PdfGoogleFonts.notoSansRegular(),
    bold: await PdfGoogleFonts.notoSansBold(),
  );
  final primary = PdfColor.fromHex('006685');
  final border = pw.TableBorder.all(color: PdfColor.fromHex('D1D5DB'), width: 0.4);
  final dateFmt = DateFormat('dd/MM/yyyy');

  final imputables = lignes.where((l) => l.imputable).toList();
  final total =
      imputables.fold<double>(0, (s, l) => s + l.valeurResiduelle);

  final lieu = [header.immeubleNom, header.chambreNom]
      .whereType<String>()
      .join(' · ');

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
        pw.Text('Décompte de réparations locatives',
            style: pw.TextStyle(
                fontSize: 16, fontWeight: pw.FontWeight.bold, color: primary)),
        pw.SizedBox(height: 4),
        if (lieu.isNotEmpty) pw.Text(lieu, style: const pw.TextStyle(fontSize: 10)),
        if (header.locataireNom != null)
          pw.Text('Locataire : ${header.locataireNom}',
              style: const pw.TextStyle(fontSize: 10)),
        pw.Text('Établi le ${dateFmt.format(header.createdAt)}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        pw.Table(
          border: border,
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(1.5),
            4: pw.FlexColumnWidth(1.5),
            5: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColor.fromHex('E0F2F8')),
              children: [
                cell('Équipement', bold: true),
                cell('Catégorie', bold: true),
                cell("Valeur d'achat", bold: true),
                cell('Âge', bold: true),
                cell('Abatt.', bold: true),
                cell('À payer', bold: true),
              ],
            ),
            for (final l in imputables)
              pw.TableRow(children: [
                cell(l.equipement),
                cell(l.categorie ?? '—'),
                cell(formatEuros(l.valeurAchat)),
                cell('${l.ageAnnees.toStringAsFixed(1)} an(s)'),
                cell('${l.abattementPct.toStringAsFixed(0)} %'),
                cell(formatEuros(l.valeurResiduelle), bold: true),
              ]),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.Text('Total à la charge du locataire : ',
                style:
                    pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(formatEuros(total),
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: primary)),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text(
          "Montants calculés en tenant compte de la vétusté (valeur d'achat "
          "diminuée d'un abattement selon l'ancienneté et la durée de vie "
          "théorique). Aucune somme n'est réclamée au titre de l'usure normale.",
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
      ],
    ),
  );
  return doc.save();
}

/// Page d'aperçu (impression / téléchargement) du décompte.
class VetustePdfPreviewPage extends StatelessWidget {
  final VetusteDecompteModel header;
  final List<VetusteDecompteLigneModel> lignes;
  const VetustePdfPreviewPage(
      {super.key, required this.header, required this.lignes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Décompte de réparations')),
      body: PdfPreview(
        build: (_) => buildVetustePdf(header, lignes),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
      ),
    );
  }
}
