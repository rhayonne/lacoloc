import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _formatter = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
final _eurosFmt =
    NumberFormat.currency(locale: 'fr_FR', symbol: '€', decimalDigits: 2);

/// Formata centavos inteiros para moeda francesa: 150000 → "1 500,00 €"
String formatFrenchCurrency(int cents) => _formatter.format(cents / 100);

/// Formata um valor já em **euros** (não centavos) para moeda francesa :
/// 1500 → "1 500,00 €". Usar para campos `valeur`/`montant` guardados em euros.
String formatEuros(num euros) => _eurosFmt.format(euros);

/// Converte o texto de um campo monetário (aceita « 1 500,50 » / « 1500.5 »)
/// para double em euros. Retorna null se vazio/inválido.
double? parseEuros(String raw) {
  final cleaned = raw
      .replaceAll(' ', '')
      .replaceAll(' ', '')
      .replaceAll(' ', '')
      .replaceAll('€', '')
      .replaceAll(',', '.')
      .trim();
  if (cleaned.isEmpty) return null;
  return double.tryParse(cleaned);
}

/// Formatter de saisie monétaire : n'autorise que des chiffres, un séparateur
/// décimal (`,` ou `.`) et au plus 2 décimales. À utiliser dans les
/// `TextField` de valeur/montant pour une saisie propre.
class CurrencyInputFormatter extends TextInputFormatter {
  final _regex = RegExp(r'^\d{0,9}([.,]\d{0,2})?$');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    return _regex.hasMatch(text) ? newValue : oldValue;
  }
}
