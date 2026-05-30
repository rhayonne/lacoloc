// Teste manual de envio de e-mail (modo `test` da edge function invite-locataire).
//
// NÃO cria nenhuma conta — apenas dispara um e-mail de diagnóstico SMTP e
// verifica a resposta (`emailSent`, `smtpError`).
//
// Como rodar:
//   flutter test test/email_smtp_test.dart
//
// O destinatário padrão é ADDR_MAIL_CONFIRMATION (do .env.dev). Para mandar
// para outro endereço:
//   flutter test test/email_smtp_test.dart --dart-define=TO=alguem@exemplo.com
//
// Lê SUPA_URL / SUP_ANNON_KEY direto do arquivo .env.dev (sem precisar de
// Supabase.initialize nem do bundle de assets).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

/// Lê pares chave='valor' de um arquivo .env simples.
Map<String, String> _parseEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('Arquivo não encontrado: $path');
  }
  final out = <String, String>{};
  for (final raw in file.readAsLinesSync()) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) continue;
    final i = line.indexOf('=');
    final key = line.substring(0, i).trim();
    var value = line.substring(i + 1).trim();
    if (value.length >= 2 &&
        ((value.startsWith("'") && value.endsWith("'")) ||
            (value.startsWith('"') && value.endsWith('"')))) {
      value = value.substring(1, value.length - 1);
    }
    out[key] = value;
  }
  return out;
}

void main() {
  test('envia e-mail de teste pela edge function invite-locataire', () async {
    final env = _parseEnv('.env.dev');
    final url = env['SUPA_URL'];
    final anon = env['SUP_ANNON_KEY'];
    expect(url, isNotNull, reason: 'SUPA_URL ausente no .env.dev');
    expect(anon, isNotNull, reason: 'SUP_ANNON_KEY ausente no .env.dev');

    const toOverride = String.fromEnvironment('TO');
    final to = toOverride.isNotEmpty
        ? toOverride
        : (env['ADDR_MAIL_CONFIRMATION'] ?? 'rhay.lopes.dev@gmail.com');

    final res = await http.post(
      Uri.parse('$url/functions/v1/invite-locataire'),
      headers: {
        'apikey': anon!,
        'Authorization': 'Bearer $anon',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'test': true,
        'fullName': 'Teste La Coloc',
        'email': to,
      }),
    );

    // ignore: avoid_print
    print('Réponse (${res.statusCode}): ${res.body}');

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    expect(
      data['emailSent'],
      isTrue,
      reason: 'Envio falhou — smtpError: ${data['smtpError'] ?? '(nenhum)'}',
    );
  }, timeout: const Timeout(Duration(seconds: 30)));
}
