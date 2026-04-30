import 'package:intl/intl.dart';

final _formatter = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

/// Formata centavos inteiros para moeda francesa: 150000 → "1 500,00 €"
String formatFrenchCurrency(int cents) => _formatter.format(cents / 100);
