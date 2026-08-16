import 'package:habitafrance/data/models/payment_methods.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Accès à `User_Payment_Methods` — les coordonnées de paiement de l'utilisateur
/// **connecté**, et de lui seul (la RLS `user_payment_methods_owner` ne connaît
/// pas d'autre cas ; il n'y a donc volontairement pas de `listByOwner(id)`).
///
/// **Pas de [DataCache] ici**, contrairement aux autres datasources : c'est une
/// seule ligne, lue puis modifiée sur le même écran. Un cache de 5 minutes y
/// ferait réapparaître l'ancien IBAN juste après un enregistrement — le défaut
/// exact qu'on ne veut pas sur des coordonnées bancaires.
class PaymentMethodsDatasource {
  PaymentMethodsDatasource._();

  static final SupabaseClient _db = Supabase.instance.client;
  static const String _table = 'User_Payment_Methods';

  /// Fiche de l'utilisateur connecté. Renvoie une fiche **vierge** s'il n'a
  /// jamais rien renseigné (pas de ligne en base) — l'écran doit s'afficher.
  /// `null` seulement si personne n'est connecté.
  static Future<PaymentMethods?> getMine() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return null;

    final row = await _db
        .from(_table)
        .select()
        .eq('user_id', uid)
        .maybeSingle();
    if (row == null) return PaymentMethods.empty(uid);
    return PaymentMethods.fromMap(row);
  }

  /// Enregistre (crée ou remplace) la fiche de l'utilisateur connecté.
  ///
  /// `user_id` est **réimposé** à partir de la session : même si l'appelant
  /// passait un modèle construit avec un autre id, la ligne écrite reste la
  /// sienne (et la RLS refuserait de toute façon).
  static Future<PaymentMethods> save(PaymentMethods input) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Aucun utilisateur connecté.');
    }

    final row = {...input.toUpsert(), 'user_id': uid};
    final saved = await _db
        .from(_table)
        .upsert(row, onConflict: 'user_id')
        .select()
        .single();
    return PaymentMethods.fromMap(saved);
  }
}
