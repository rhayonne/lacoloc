import 'package:flutter/material.dart';
import 'package:habitafrance/data/datasources/signatures.dart';
import 'package:habitafrance/data/models/etat_de_lieux.dart';
import 'package:habitafrance/presentation/users/proprietaires/edl_pdf_preview_page.dart';
import 'package:habitafrance/utils/signature_pad.dart';

/// Flux de signature côté **locataire** (« Accepter et signer ») :
/// 1. Vérifie que l'utilisateur a une signature ; sinon ouvre l'écran de
///    création de signature.
/// 2. Affiche l'aperçu du document PDF de l'EDL avec un bouton « Signer ».
/// 3. Retourne l'URL de signature à enregistrer **si** l'utilisateur confirme,
///    ou `null` s'il annule à une étape quelconque.
///
/// L'appelant n'a plus qu'à appeler `EtatDesLieuxDatasource.locataireAccepter`
/// avec l'URL retournée.
Future<String?> runLocataireSignatureFlow(
  BuildContext context,
  EtatDesLieuxModel edl,
) async {
  // 1) Signature : récupérer la sauvegardée, sinon proposer d'en créer une.
  String? sigUrl = await SignaturesDatasource.getSavedUrl();
  if (!context.mounted) return null;
  if (sigUrl == null) {
    final res = await showSignatureDialog(context);
    if (res == null || !context.mounted) return null;
    sigUrl = res.url;
  }

  // 2) Aperçu du document avec bouton « Signer et accepter ».
  final bool? confirmed;
  if (edl.partie == PartieEdl.privative && edl.edlCollectifId != null) {
    confirmed = await openEdlIndividuelPdfPreview(
      context: context,
      collectifId: edl.edlCollectifId!,
      privatifId: edl.id,
      enableSign: true,
    );
  } else {
    confirmed = await openEdlCollectifPdfPreview(
      context: context,
      edlId: edl.id,
      enableSign: true,
    );
  }
  if (confirmed != true) return null;

  return sigUrl;
}
