import 'package:flutter/material.dart';
import 'package:lacoloc_front/presentation/my_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  await dotenv.load();

  final apiUrl = dotenv.get('SUPA_URL');
  final apiAnoKey = dotenv.get('SUP_ANNON_KEY');

  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(url: apiUrl, anonKey: apiAnoKey);
  runApp(MyApp());
}
