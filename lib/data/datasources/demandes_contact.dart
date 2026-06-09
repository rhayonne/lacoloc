import 'package:lacoloc_front/data/cache/data_cache.dart';
import 'package:lacoloc_front/data/cache/realtime_service.dart';
import 'package:lacoloc_front/data/models/demande_contact.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DemandesContactDatasource {
  DemandesContactDatasource._();

  static final _db = Supabase.instance.client;
  static const _table = 'Demandes_Contact';

  static final _cache = DataCache.instance;
  static void _invalidate() => _cache.invalidatePrefix(CacheKeys.demandes);

  /// Cria uma nova demanda de contato pelo locataire autenticado.
  static Future<void> create({
    required String locataireId,
    required int immeubleId,
    int? chambreId,
  }) async {
    final payload = <String, dynamic>{
      'locataire_id': locataireId,
      'immeuble_id': immeubleId,
      'contact_etabli': false,
    };
    if (chambreId != null) payload['chambre_id'] = chambreId;
    await _db.from(_table).insert(payload);
    _invalidate();
  }

  /// Lista todas as demandas para os imóveis do proprietaire autenticado.
  static Future<List<DemandeContactModel>> listByOwner({
    bool refresh = false,
  }) {
    return _cache.get('${CacheKeys.demandes}owner', () async {
      final rows = await _db
          .from(_table)
          .select(
            '*, '
            'Users_Client!locataire_id(full_name, email, phone, age, date_of_birth), '
            'Chambres!chambre_id(room_name), '
            'Immeubles!immeuble_id(name)',
          )
          .order('created_at', ascending: false);

      return rows
          .map((r) => DemandeContactModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }, refresh: refresh);
  }

  /// Atualiza o campo contact_etabli de uma demanda.
  static Future<void> updateContactEtabli(int id, {required bool value}) async {
    await _db.from(_table).update({'contact_etabli': value}).eq('id', id);
    _invalidate();
  }

  /// Verifica se já existe uma demanda pendente (contact_etabli = false)
  /// do mesmo locataire para a mesma chambre.
  static Future<bool> hasDemandeEnAttente({
    required String locataireId,
    required int chambreId,
  }) async {
    final res = await _db
        .from(_table)
        .select('id')
        .eq('locataire_id', locataireId)
        .eq('chambre_id', chambreId)
        .eq('contact_etabli', false)
        .limit(1);
    return (res as List).isNotEmpty;
  }
}
