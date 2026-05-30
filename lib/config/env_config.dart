import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Sélection de l'environnement et chargement du fichier `.env` correspondant.
///
/// L'environnement est choisi au build via `--dart-define=ENV=dev|prod`
/// (par défaut `dev`). Chaque environnement a son propre fichier :
/// `.env.dev` / `.env.prod`.
///
/// Exemples :
/// ```
/// flutter run                              # dev (défaut)
/// flutter run --dart-define=ENV=prod       # prod
/// flutter build web --dart-define=ENV=prod # build de prod
/// ```
class EnvConfig {
  EnvConfig._();

  /// Nom de l'environnement courant : `dev` ou `prod`.
  static const String env = String.fromEnvironment('ENV', defaultValue: 'dev');

  static bool get isProd => env == 'prod';
  static bool get isDev => !isProd;

  /// Fichier `.env` correspondant à l'environnement sélectionné.
  static String get fileName => '.env.$env';

  /// Charge le fichier `.env` de l'environnement courant dans `dotenv`.
  static Future<void> load() => dotenv.load(fileName: fileName);
}
