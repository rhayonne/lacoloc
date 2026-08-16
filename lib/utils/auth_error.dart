import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduit une erreur d'authentification (gotrue) ou réseau en message clair
/// en français. Réutilisable partout où l'on appelle l'auth.
///
/// Priorité : code gotrue (API v20240101+) → message string (legacy) → réseau.
String authErrorMessage(Object error) {
  // Timeout côté client (.timeout()).
  if (error is TimeoutException) {
    return 'La connexion a expirée. Vérifiez votre connexion internet et réessayez.';
  }

  // Erreur réseau avant de recevoir une réponse (CORS, connection refused…).
  if (error is AuthRetryableFetchException) {
    return 'Connexion impossible. Vérifiez votre connexion internet et réessayez.';
  }

  if (error is AuthException) {
    final code = error.code ?? '';
    final msg = error.message.toLowerCase();

    // ── Vérification par code (gotrue API v20240101) ──────────────────────
    if (code == 'invalid_credentials' || code == 'invalid_grant') {
      return 'E-mail ou mot de passe incorrect.';
    }
    if (code == 'email_not_confirmed') {
      return "Votre e-mail n'a pas encore été confirmé. Consultez votre boîte mail.";
    }
    if (code == 'user_not_found') {
      return "Aucun compte n'existe avec cet e-mail.";
    }
    if (code == 'email_exists' || code == 'user_already_exists') {
      return 'Un compte existe déjà avec cet e-mail.';
    }
    if (code == 'over_email_send_rate_limit' ||
        code == 'over_request_rate_limit' ||
        code == 'email_rate_limit_exceeded') {
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    }
    if (code == 'weak_password') {
      return 'Mot de passe trop faible. Choisissez un mot de passe plus sécurisé.';
    }

    // ── Fallback : vérification par message (format legacy) ───────────────
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'E-mail ou mot de passe incorrect.';
    }
    if (msg.contains('email not confirmed')) {
      return "Votre e-mail n'a pas encore été confirmé.";
    }
    if (msg.contains('user not found') || error.statusCode == '404') {
      return "Aucun compte n'existe avec cet e-mail.";
    }
    if (msg.contains('already registered') ||
        msg.contains('already been registered') ||
        msg.contains('user already exists')) {
      return 'Un compte existe déjà avec cet e-mail.';
    }
    if (msg.contains('rate limit') || error.statusCode == '429') {
      return 'Trop de tentatives. Réessayez dans quelques minutes.';
    }
    if (msg.contains('password')) {
      return 'Mot de passe invalide ou incorrect.';
    }

    // ── Le trigger a refusé la ligne pendant l'inscription ──────────────
    // Quand un trigger sur `Users_Client` refuse l'insertion, GoTrue renvoie
    // un message générique (« Database error saving new user ») **sans** le
    // détail Postgres : impossible de reconnaître la contrainte. Or
    // l'inscription publique ne peut pas vérifier le numéro au préalable — la
    // RPC `phone_exists` est réservée aux gestionnaires, et l'ouvrir à `anon`
    // créerait un oracle d'énumération. On oriente donc vers la seule cause
    // probable et vers une sortie concrète, plutôt qu'une erreur opaque.
    if (msg.contains('database error saving new user') ||
        (msg.contains('unexpected_failure') &&
            msg.contains('saving new user'))) {
      return 'Impossible de créer le compte. Si vous avez renseigné un numéro '
          'de téléphone, il est peut-être déjà utilisé : réessayez en laissant '
          'le champ vide, vous pourrez l\'ajouter ensuite dans « Mon Profil ».';
    }

    // Message gotrue brut en dernier recours (déjà lisible).
    return error.message.isNotEmpty
        ? error.message
        : 'Erreur d\'authentification. Veuillez réessayer.';
  }

  // ── Unicité en base (Postgres 23505) ────────────────────────────────────
  // L'inscription passe par un trigger qui insère dans `Users_Client` : une
  // collision d'e-mail ou de téléphone remonte donc comme une erreur Postgres,
  // pas comme une AuthException. Sans ce cas, l'utilisateur voyait le texte
  // brut « duplicate key value violates unique constraint … ».
  final brut = error.toString();
  final estDoublon = (error is PostgrestException && error.code == '23505') ||
      brut.contains('23505') ||
      brut.toLowerCase().contains('duplicate key');
  if (estDoublon) {
    // Le trigger `users_client_phone_unique_locataire` lève déjà un message
    // rédigé en français, plus précis que ce qu'on écrirait ici (il dit
    // « un autre compte locataire ») : on le préfère quand il nous parvient.
    if (error is PostgrestException &&
        error.message.startsWith('Ce numéro de téléphone')) {
      return error.message;
    }
    if (brut.contains('users_client_phone_unique')) {
      return 'Ce numéro de téléphone est déjà utilisé par un autre compte '
          'locataire.';
    }
    if (brut.contains('users_client_email_unique_ci')) {
      return 'Un compte existe déjà avec cet e-mail.';
    }
    return 'Ces informations sont déjà utilisées par un autre compte.';
  }

  // Erreurs réseau hors gotrue (ClientException / XMLHttpRequest / socket…).
  final s = error.toString().toLowerCase();
  if (s.contains('failed to fetch') ||
      s.contains('socketexception') ||
      s.contains('clientexception') ||
      s.contains('xmlhttprequest') ||
      s.contains('connection refused') ||
      s.contains('network')) {
    return 'Connexion impossible. Vérifiez votre connexion internet et réessayez.';
  }

  return 'Une erreur est survenue. Veuillez réessayer.';
}
