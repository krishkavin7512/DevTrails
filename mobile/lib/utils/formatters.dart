import 'package:intl/intl.dart';

class Fmt {
  static String inr(int paise) =>
      '₹${(paise / 100).toStringAsFixed(0)}';

  static String inrDecimal(int paise) =>
      NumberFormat.currency(locale: 'en_IN', symbol: '₹')
          .format(paise / 100);

  static String date(DateTime dt) =>
      DateFormat('dd MMM yyyy').format(dt);

  static String dateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(dt);

  static String timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
