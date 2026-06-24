import 'package:flutter/material.dart';
import 'package:lacoloc_front/data/datasources/etat_de_lieux.dart';
import 'package:lacoloc_front/data/datasources/notifications.dart';
import 'package:lacoloc_front/data/datasources/signatures.dart';
import 'package:lacoloc_front/data/models/etat_de_lieux.dart';
import 'package:lacoloc_front/presentation/users/proprietaires/bail_pdf_data.dart';
import 'package:lacoloc_front/theme/app_theme.dart';
import 'package:lacoloc_front/utils/signature_pad.dart';

/// Résultat du flux « garant » sur un bail.
typedef BailGarantResult = ({EtatDesLieuxModel edl, bool blocked});

/// Vérifie, **à la génération du bail** par le propriétaire, si le bail
/// nécessite un garant :
/// 1. Si le choix n'a pas encore été fait (`bailAvecGarant == null`), pose la
///    question « Ce bail nécessite-t-il un garant ? » (Oui/Non) et l'enregistre.
/// 2. Si un garant est requis mais que le locataire n'en a enregistré aucun :
///    - notifie le locataire (in-app → Messages + tableau de bord) ;
///    - prévient le propriétaire ;
///    - retourne `blocked: true` → l'impression du bail sera bloquée.
///
/// Retourne `null` uniquement si le propriétaire ferme la question sans choisir
/// (l'appelant n'ouvre alors pas le bail). Réservé au rôle propriétaire.
Future<BailGarantResult?> ensureBailGarant(
  BuildContext context,
  EtatDesLieuxModel edl,
) async {
  var current = edl;

  // 1) Décision si pas encore prise.
  if (current.bailAvecGarant == null) {
    final avecGarant = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Garant du bail'),
        content: const Text(
          'Ce bail nécessite-t-il un garant (caution) ?\n\n'
          "Si oui, le locataire devra enregistrer au moins un garant et le bail "
          "ne pourra être imprimé qu'une fois ce garant renseigné.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Non, sans garant'),
          ),
          FilledButton(
            style: AppTheme.saveButtonStyle,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Oui, avec garant'),
          ),
        ],
      ),
    );
    if (!context.mounted) return null;
    if (avecGarant == null) return null; // fermé → on annule l'ouverture
    await EtatDesLieuxDatasource.setBailAvecGarant(current.id, avecGarant);
    current = await EtatDesLieuxDatasource.findById(current.id) ?? current;
  }

  // 2) Garant requis → vérifier qu'au moins un est enregistré.
  if (current.bailAvecGarant == true) {
    final garants = await BailPdfData.garantsForEdl(current);
    if (garants.isEmpty) {
      // Notifier le locataire (apparaît dans « Messages » + tableau de bord).
      await NotificationsDatasource.notifyEdlLocataire(
        edlId: current.id,
        type: 'bail_garant_requis',
        title: 'Garant requis pour votre bail',
        body: "Votre bailleur demande l'enregistrement d'au moins un garant "
            "(caution) pour votre bail. Rendez-vous dans « Documents › Garants » "
            "pour en ajouter un.",
      );
      if (context.mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Garant manquant'),
            content: const Text(
              "Le locataire n'a pas encore enregistré de garant. "
              "Une demande vient de lui être envoyée.\n\n"
              "Vous pouvez consulter le bail, mais il ne pourra être imprimé "
              "qu'une fois au moins un garant enregistré.",
            ),
            actions: [
              FilledButton(
                style: AppTheme.saveButtonStyle,
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Compris'),
              ),
            ],
          ),
        );
      }
      return (edl: current, blocked: true);
    }
  }

  return (edl: current, blocked: false);
}

/// Vérifie qu'une signature est apposée sur le bail [edl] **avant** de l'ouvrir
/// (aperçu / impression), pour le [role] indiqué (`proprietaire` = bailleur,
/// `locataire`). Flux :
/// 1. Si le bail porte déjà la signature du rôle → retourne l'EDL tel quel.
/// 2. Sinon, propose dans un pop-up d'y apposer sa signature.
///    - « Continuer sans signer » → retourne l'EDL inchangé (consultation).
///    - « Signer » → récupère la signature sauvegardée ; à défaut, ouvre le
///      pop-up de création de signature ; puis l'enregistre sur le bail et
///      retourne l'EDL mis à jour (avec l'URL de signature).
///
/// Retourne `null` uniquement si l'utilisateur ferme/annule entièrement le flux
/// (l'appelant n'ouvre alors pas le document).
Future<EtatDesLieuxModel?> ensureBailSignature(
  BuildContext context,
  EtatDesLieuxModel edl, {
  required String role,
}) async {
  final bool isLocataire = role == 'locataire';
  final String? existing =
      isLocataire ? edl.locataireSignatureUrl : edl.proprietaireSignatureUrl;

  // 1) Déjà signé par ce rôle → rien à faire.
  if (existing != null) return edl;

  // 2) Demander à l'utilisateur s'il veut signer.
  final choice = await showDialog<_SignChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Bail non signé'),
      content: Text(
        isLocataire
            ? "Ce bail ne porte pas encore votre signature. "
                "Voulez-vous y apposer votre signature maintenant ?"
            : "Ce bail ne porte pas encore votre signature. "
                "Voulez-vous y apposer votre signature de bailleur maintenant ?",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_SignChoice.skip),
          child: const Text('Continuer sans signer'),
        ),
        FilledButton.icon(
          style: AppTheme.saveButtonStyle,
          onPressed: () => Navigator.of(ctx).pop(_SignChoice.sign),
          icon: const Icon(Icons.draw_outlined, size: 18),
          label: const Text('Signer'),
        ),
      ],
    ),
  );

  if (!context.mounted) return null;
  if (choice == null) return null; // fermé sans choisir → on annule l'ouverture
  if (choice == _SignChoice.skip) return edl; // consultation sans signature

  // 3) Récupérer la signature sauvegardée, sinon proposer d'en créer une.
  String? sigUrl = await SignaturesDatasource.getSavedUrl();
  if (!context.mounted) return null;
  if (sigUrl == null) {
    final res = await showSignatureDialog(context);
    if (res == null || !context.mounted) return null; // annulé → on n'ouvre pas
    sigUrl = res.url;
  }

  // 4) Apposer la signature sur le bail, puis relire l'EDL à jour (pour que
  //    l'aperçu/PDF affiche bien la signature fraîchement enregistrée).
  try {
    await EtatDesLieuxDatasource.setBailSignature(
      id: edl.id,
      role: role,
      signatureUrl: sigUrl,
    );
    return await EtatDesLieuxDatasource.findById(edl.id) ?? edl;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d\'enregistrer la signature : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return null;
  }
}

enum _SignChoice { sign, skip }
