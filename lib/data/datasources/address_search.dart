import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:habitafrance/data/models/address_suggestion.dart';

class AddressSearchService {
  static Future<List<AddressSuggestion>> search(String query) async {
    if (query.trim().length < 3) return const [];
    try {
      // API officielle de géocodage (BAN). L'ancien domaine
      // api-adresse.data.gouv.fr est déprécié/sunset depuis le 31/01/2026 et
      // redirige vers data.geopf.fr — même format de réponse GeoJSON.
      final uri = Uri.https('data.geopf.fr', '/geocodage/search/', {
        'q': query.trim(),
        'limit': '6',
        'autocomplete': '1',
      });
      final response =
          await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return const [];
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? [];
      return features
          .map((f) => AddressSuggestion.fromProperties(
              (f as Map<String, dynamic>)['properties']
                  as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
