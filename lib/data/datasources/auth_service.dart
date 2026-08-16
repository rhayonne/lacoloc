import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:habitafrance/data/models/profile_visibility.dart';
import 'package:habitafrance/data/models/theme_ref.dart';
import 'package:habitafrance/data/models/users_client.dart';
import 'package:habitafrance/theme/theme_controller.dart';
import 'package:habitafrance/utils/auth_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado tratado de uma tentativa de login.
/// Ou `response` (sucesso) ou `errorMessage` (mensagem FR pronta p/ exibir).
class SignInResult {
  final AuthResponse? response;
  final String? errorMessage;

  const SignInResult.success(this.response) : errorMessage = null;
  const SignInResult.failure(this.errorMessage) : response = null;

  bool get isSuccess => response != null;
}

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

  /// Login por email/senha. **Único** serviço de login do app (usado pelo
  /// pop-up [LoginCard]). **Nunca lança** e nunca deixa um erro "não capturado".
  ///
  /// O gotrue lança `AuthApiException` num 400 (credenciais inválidas). Em
  /// Flutter web (DDC), conforme o contexto de chamada (ex.: tecla Entrée → o
  /// rebuild do `unfocus`), esse erro pode ser **desviado para a zona como
  /// erro não capturado** em vez de cair no `.catchError` — e então o DevTools
  /// **pausa no `throw`** (errors.dart) e parece que o app travou.
  ///
  /// Por isso envolvemos a chamada num `runZonedGuarded` **local** (não em torno
  /// de `runApp`, logo sem "Zone mismatch"): ele captura tanto o erro normal
  /// (try/catch) quanto qualquer erro desviado para a zona. Resultado: o erro é
  /// **sempre** interceptado → o debugger não pausa mais nele, e o spinner
  /// nunca fica preso. Um `Completer` garante resolução única e o `.timeout` é
  /// a última rede.
  static Future<SignInResult> signIn({
    required String email,
    required String password,
  }) {
    debugPrint('[login] tentative de connexion');
    final completer = Completer<SignInResult>();

    void finish(SignInResult result) {
      if (!completer.isCompleted) completer.complete(result);
    }

    void logError(String origine, Object e) {
      debugPrint('[login] ÉCHEC ($origine) — erreur Supabase capturée:');
      debugPrint('  type:    ${e.runtimeType}');
      debugPrint('  détail:  $e');
      if (e is AuthException) {
        debugPrint('  code:    ${e.code}');
        debugPrint('  status:  ${e.statusCode}');
        debugPrint('  message: ${e.message}');
      }
    }

    runZonedGuarded(
      () {
        _client.auth
            .signInWithPassword(email: email, password: password)
            .then((res) {
              // ⚠️ Ne JAMAIS loguer la session complète ni l'email : la session
              // contient l'access_token/refresh_token (vol de session via un
              // simple copier-coller de console) et l'email est une PII.
              debugPrint('[login] SUCCÈS — user: ${res.user?.id}');
              finish(SignInResult.success(res));
            })
            .catchError((Object e) {
              logError('catchError', e);
              finish(SignInResult.failure(authErrorMessage(e)));
            });
      },
      // Erreur détournée vers la zone (cas DDC) : on l'intercepte ici pour
      // qu'elle ne soit JAMAIS "non interceptée".
      (e, st) {
        logError('zone', e);
        finish(SignInResult.failure(authErrorMessage(e)));
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        debugPrint('[login] TIMEOUT — la requête n\'a pas répondu à temps');
        return SignInResult.failure(
          'La connexion a expiré. Vérifiez vos identifiants et votre '
          'connexion, puis réessayez.',
        );
      },
    );
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

  /// Notifica o admin sobre novo cadastro de proprietaire.
  /// Falha silenciosamente — não bloqueia o fluxo principal.
  ///
  /// Só `email` e `note` vão para o servidor: o **nome e o telefone são
  /// relidos de `Users_Client`** pela edge function (service role). Enviá-los
  /// daqui não teria efeito e daria a falsa impressão de que o conteúdo do
  /// e-mail vem do cliente — foi essa confiança que permitia injetar HTML na
  /// caixa do administrador. Os parâmetros continuam aceites (opcionais) para
  /// não quebrar chamadores antigos, mas são **ignorados**.
  static Future<void> notifyProprietaireRegistration({
    required String email,
    String? fullName,
    String? phone,
    String? note,
  }) async {
    try {
      await _client.functions.invoke(
        'notify-proprietaire',
        body: {
          'email': email,
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

  /// Enregistre les champs que l'utilisateur accepte de montrer à l'autre
  /// partie (`Users_Client.profile_visibility`).
  ///
  /// Lève si l'écriture échoue : un choix de confidentialité perdu en silence
  /// ferait croire à l'utilisateur qu'un champ est masqué alors qu'il ne l'est
  /// pas. **Rétro-compat** : sur une base sans la migration
  /// `20260815174659_users_client_profile_visibility`, l'appel échoue
  /// explicitement (colonne inconnue) — l'écran le signale.
  static Future<void> updateProfileVisibility(
    ProfileVisibility visibility,
  ) async {
    final user = currentUser;
    if (user == null) return;
    await _client
        .from(_profileTable)
        .update({'profile_visibility': visibility.toJson()})
        .eq('id', user.id);
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

  // ── Thème choisi par l'utilisateur ────────────────────────────────────────
  // La préférence vit en base (`Users_Client.theme_preference`) pour suivre la
  // personne d'un appareil à l'autre. Le `ThemeController` ne connaît que la
  // valeur courante ; la persistance est ici, dans la couche données.

  /// Applique le thème enregistré de l'utilisateur connecté. Appelé à la
  /// connexion. Son choix l'emporte sur le thème principal ; s'il n'a rien
  /// choisi (ou si son thème a été désactivé depuis), il voit le principal.
  /// Best-effort : si la lecture échoue, on garde le thème courant plutôt que
  /// de bloquer l'ouverture de session.
  static Future<void> loadThemePreference() async {
    final user = currentUser;
    if (user == null) return;
    try {
      final row = await _client
          .from(_profileTable)
          .select('theme_preference')
          .eq('id', user.id)
          .maybeSingle();
      await ThemeController.instance.applyUserPreference(
        row?['theme_preference'] as String?,
      );
    } catch (_) {
      // Thème = confort, pas une donnée critique : on n'interrompt rien.
    }
  }

  /// Enregistre le thème choisi et l'applique immédiatement.
  /// Lève si l'écriture échoue, pour que l'écran puisse le dire à
  /// l'utilisateur (sinon son choix serait perdu au prochain démarrage sans
  /// qu'il le sache).
  static Future<void> saveThemePreference(ThemeRef theme) async {
    ThemeController.instance.set(theme);
    final user = currentUser;
    if (user == null) return;
    await _client
        .from(_profileTable)
        .update({'theme_preference': theme.code})
        .eq('id', user.id);
  }
}
