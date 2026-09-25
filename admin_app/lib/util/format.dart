import 'package:intl/intl.dart';

final _rs = NumberFormat.currency(locale: 'en_LK', symbol: 'Rs. ', decimalDigits: 0);
final _rsMillions = NumberFormat('#,##0.##', 'en_LK');

/// "Rs. 125,000" — whole rupees, as the hire cards show money.
String formatRs(double value) => _rs.format(value);

/// Like [formatRs], but from a million up it reads "Rs. 1.25M" — for the
/// narrow tiles that sit four to a row.
String formatRsShort(double value) {
  if (value.abs() >= 1000000) return 'Rs. ${_rsMillions.format(value / 1000000)}M';
  return _rs.format(value);
}

/// "1 hire" / "3 hires".
String countOf(int count, String singular, [String? plural]) =>
    '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';
