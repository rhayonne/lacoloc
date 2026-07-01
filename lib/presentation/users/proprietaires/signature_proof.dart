import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Un signataire pour le cachet de preuve (rôle + identité authentifiée + date).
class ProofSigner {
  final String role; // « Le bailleur », « Le locataire »…
  final String? name;
  final String? email; // e-mail du compte authentifié (preuve d'identité)
  final String? signedAt; // horodatage déjà formaté (dd/MM/yyyy) ou null

  const ProofSigner({
    required this.role,
    this.name,
    this.email,
    this.signedAt,
  });
}

/// Calcule l'empreinte d'intégrité (SHA-256) des données canoniques d'un
/// document signé. On hache les **données** du contrat (parties, bien, montants,
/// dates, URLs de signature…), pas le PDF rendu (ce qui serait circulaire).
/// Retourne une chaîne hexadécimale en majuscules, groupée par blocs de 8.
String integrityFingerprint(List<Object?> parts) {
  final canonical = parts.map((e) => e?.toString() ?? '').join('|');
  final digest = sha256.convert(utf8.encode(canonical)).toString().toUpperCase();
  final buf = StringBuffer();
  for (var i = 0; i < digest.length; i += 8) {
    if (i > 0) buf.write(' ');
    buf.write(digest.substring(i, (i + 8).clamp(0, digest.length)));
  }
  return buf.toString();
}

/// Bloc « Cachet de signature électronique » à insérer en fin de document
/// (bail / EDL). Matérialise le **faisceau d'indices** (signature électronique
/// simple renforcée) : identité du compte authentifié, horodatage, empreinte
/// d'intégrité et mentions légales (eIDAS + art. 1366-1367 du Code civil).
pw.Widget buildSignatureProofBlock({
  required List<ProofSigner> signers,
  required String fingerprint,
  required pw.TextStyle base,
  required pw.TextStyle bold,
  PdfColor borderColor = PdfColors.grey600,
}) {
  final small = base.copyWith(fontSize: 8.5, color: PdfColors.grey800);
  final signed = signers.where((s) => s.signedAt != null).toList();

  return pw.Container(
    margin: const pw.EdgeInsets.only(top: 14),
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: borderColor, width: 0.8),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Cachet de signature électronique', style: bold),
        pw.SizedBox(height: 4),
        pw.Text(
          'Ce document a été signé électroniquement. Conformément au règlement '
          'européen eIDAS n° 910/2014 et aux articles 1366 et 1367 du Code civil, '
          "l'écrit électronique a la même force probante que l'écrit papier "
          "dès lors que peut être dûment identifiée la personne dont il émane et "
          "que son intégrité est garantie.",
          style: small,
        ),
        pw.SizedBox(height: 6),
        for (final s in signed)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              '• ${s.role} : ${s.name ?? '—'}'
              '${s.email != null ? ' (compte : ${s.email})' : ''} — '
              'signé le ${s.signedAt}.',
              style: small,
            ),
          ),
        if (signed.isEmpty)
          pw.Text('• En attente de signature des parties.', style: small),
        pw.SizedBox(height: 6),
        pw.Text('Empreinte d\'intégrité (SHA-256) :', style: small),
        pw.Text(fingerprint,
            style: small.copyWith(
                fontWeight: pw.FontWeight.bold, letterSpacing: 0.3)),
        pw.SizedBox(height: 6),
        pw.Text(
          'Validité — la fiabilité de cette signature repose sur un faisceau '
          "d'indices : authentification du compte de chaque signataire, "
          "horodatage de la signature, conservation de l'empreinte d'intégrité "
          'ci-dessus et traçabilité des actions. En cas de contestation, ces '
          'éléments permettent de prouver l\'identité des signataires, leur '
          'consentement et l\'intégrité du document.',
          style: small,
        ),
      ],
    ),
  );
}
