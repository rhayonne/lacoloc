import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localization/flutter_localization.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:lacoloc_front/config/env_config.dart';
import 'package:lacoloc_front/presentation/my_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // URLs sans « # » sur le web : libère le fragment pour les tokens Supabase
  // (lien d'invitation/confirmation) et active les routes par chemin.
  if (kIsWeb) usePathUrlStrategy();

  // Charge .env.dev ou .env.prod selon --dart-define=ENV (défaut: dev).
  await EnvConfig.load();

  final apiUrl = dotenv.get('SUPA_URL');
  final apiAnoKey = dotenv.get('SUP_ANNON_KEY');
  await Supabase.initialize(url: apiUrl, anonKey: apiAnoKey);
  await FlutterLocalization.instance.ensureInitialized();

  runApp(MyApp());
}
