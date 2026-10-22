import 'package:intl/intl.dart';

class Formatters {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_VE',
    symbol: r'$',
    decimalDigits: 2,
  );

  static final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  static final DateFormat _dateTimeFormat = DateFormat('dd/MM/yyyy hh:mm a');
  static final DateFormat _isoDateFormat = DateFormat('yyyy-MM-dd');

  static String currency(num amount) => _currencyFormat.format(amount);
  static String date(DateTime date) => _dateFormat.format(date);
  static String dateTime(DateTime date) => _dateTimeFormat.format(date);
  static String isoDate(DateTime date) => _isoDateFormat.format(date);

  static DateTime? parseIsoDate(String? str) {
    if (str == null || str.isEmpty) return null;
    return DateTime.tryParse(str);
  }
}
