import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Camada fina sobre `Supabase.auth` + tabela `Users_Client`.
/// Centraliza login, cadastro e leitura do perfil.
class AuthService {
  AuthService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _profileTable = 'Users_Client';

  static User? get currentUser => _client.auth.currentUser;

  static Stream<AuthState> get onAuthStateChange =>
      _client.auth.onAuthStateChange;

  static bool get isLoggedIn => currentUser != null;

  /// Login por email/senha.
  static Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Cadastro. O trigger `on_auth_user_created` (SECURITY DEFINER) cria a linha
  /// em `Users_Client` automaticamente — não inserimos aqui para evitar conflito
  /// de RLS (o cliente ainda é `anon` antes da confirmação de e-mail).
  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required UserType type,
    String? fullName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'type_client': type.raw,
      },
    );
  }

  static Future<void> signOut() => _client.auth.signOut();

  /// Carrega o perfil atual incluindo o join com User_Types_Reference.
  static Future<UsersClient?> loadCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client
        .from(_profileTable)
        .select('*, User_Types_Reference!type_user_id(id, code, label, description)')
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return UsersClient.fromJson(row);
  }
}
