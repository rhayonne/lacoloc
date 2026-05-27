import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lacoloc_front/data/models/users_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Camada fina sobre `Supabase.auth` + tabela `Users_Client`.
/// Centraliza login, cadastro e leitura do perfil.
class AuthService {
  AuthService._();

  static final SupabaseClient _client = Supabase.instance.client;
  static const String _profileTable = 'Users_Client';

  static String get _redirectTo => dotenv.get(
    'URL_EMAIL_CONFIRMATION',
    fallback: 'http://localhost:44785/confirmation-locataire',
  );

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
    String? phone,
    int? age,
    DateTime? dateOfBirth,
  }) {
    final data = <String, dynamic>{
      'full_name': fullName,
      'type_code': type.raw,
    };
    if (phone != null && phone.isNotEmpty) data['phone'] = phone;
    if (age != null) data['age'] = age;
    if (dateOfBirth != null) {
      data['date_of_birth'] = dateOfBirth.toIso8601String().substring(0, 10);
    }
    return _client.auth.signUp(
      email: email,
      password: password,
      data: data,
      emailRedirectTo: _redirectTo,
    );
  }

  /// Desconecta em TODOS os dispositivos e invalida o refresh token no servidor.
  /// `SignOutScope.global` revoga a sessão server-side — mesmo que outra pessoa
  /// tenha copiado o refresh token, ele se torna inválido imediatamente.
  static Future<void> signOut() =>
      _client.auth.signOut(scope: SignOutScope.global);

  static Future<void> deleteAccount() async {
    final res = await _client.functions.invoke('delete-account');
    final data = res.data;
    if (data is Map && data['error'] != null) {
      throw Exception(data['error'] as String);
    }
  }

  /// Notifica o admin (FORM_NEW_PROPRIETAIRE) sobre novo cadastro de proprietaire.
  /// Falha silenciosamente — não bloqueia o fluxo principal.
  static Future<void> notifyProprietaireRegistration({
    required String fullName,
    required String email,
    String? phone,
    String? note,
  }) async {
    try {
      await _client.functions.invoke(
        'notify-proprietaire',
        body: {
          'fullName': fullName,
          'email': email,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (note != null && note.isNotEmpty) 'note': note,
        },
      );
    } catch (_) {
      // Notificação é best-effort.
    }
  }

  /// Atualiza campos editáveis do perfil na tabela Users_Client.
  static Future<void> updateProfile({
    String? fullName,
    String? phone,
    int? age,
    DateTime? dateOfBirth,
  }) async {
    final user = currentUser;
    if (user == null) return;
    final updates = <String, dynamic>{};
    if (fullName != null) updates['full_name'] = fullName;
    if (phone != null) updates['phone'] = phone;
    if (age != null) updates['age'] = age;
    if (dateOfBirth != null) {
      updates['date_of_birth'] = dateOfBirth.toIso8601String().substring(0, 10);
    }
    if (updates.isEmpty) return;
    await _client.from(_profileTable).update(updates).eq('id', user.id);
  }

  /// Carrega o perfil atual incluindo o join com User_Types_Reference.
  static Future<UsersClient?> loadCurrentProfile() async {
    final user = currentUser;
    if (user == null) return null;
    final row = await _client
        .from(_profileTable)
        .select(
          '*, User_Types_Reference!type_user_id(id, code, label, description)',
        )
        .eq('id', user.id)
        .maybeSingle();
    if (row == null) return null;
    return UsersClient.fromJson(row);
  }
}
