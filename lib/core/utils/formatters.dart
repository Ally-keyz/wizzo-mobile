import 'package:intl/intl.dart';

import '../currency/currencies.dart';
import '../currency/currency_controller.dart';
import '../currency/currency_service.dart';

/// Formats a base-RWF number into the selected display currency, e.g.
/// `$1,234.56` or `RWF 1,234,567`. See [formatFromBase].
String formatMoney(num? value) {
  final state = currencyController.value;
  if (value == null) return '0 ${state.code}';
  return formatFromBase(value, state.code, state.rates);
}

/// Compact money, e.g. `$1.2M` or `KSh 1.2M`.
String formatMoneyCompact(num? value) {
  final state = currencyController.value;
  if (value == null) return '0 ${state.code}';
  final def = currencyDef(state.code);
  final v = convertFromBase(value, state.code, state.rates);
  final safe = v < 0 ? 0 : v;
  final compact = NumberFormat.compact(locale: 'en').format(safe);
  return '${def.symbol} $compact';
}

/// `Jul 12, 2025` style date.
String formatDate(DateTime? date) {
  if (date == null) return '';
  return DateFormat('MMM d, yyyy').format(date);
}

/// `Jul 12, 2025 • 14:05`
String formatDateTime(DateTime? date) {
  if (date == null) return '';
  return DateFormat('MMM d, yyyy • HH:mm').format(date);
}

/// Relative chat timestamp: `now`, `5m`, `3h`, `Yesterday` or a short date.
String chatTime(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24 && now.day == date.day) return '${diff.inHours}h';
  if (diff.inHours < 48 && now.day - date.day == 1) return 'Yesterday';
  if (now.year == date.year) return DateFormat('MMM d').format(date);
  return DateFormat('MMM d, yyyy').format(date);
}

/// Relative long-form date helper for notification/order lists.
String relativeDate(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  final diff = now.difference(date);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) {
    return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  if (diff.inDays < 7) {
    return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
  }
  return formatDate(date);
}

/// Remaining countdown like `02:14:45` or `5d 02:14`.
String countdown(DateTime? endsAt) {
  if (endsAt == null) return '00:00';
  var diff = endsAt.difference(DateTime.now());
  if (diff.isNegative) diff = Duration.zero;
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  final s = diff.inSeconds % 60;
  if (h >= 24) {
    return '${h ~/ 24}d ${(h % 24).toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// How long ago a seller's last seen was, e.g. `Last seen 2h ago`.
String lastSeen(DateTime? date) {
  if (date == null) return '';
  return 'Last seen ${relativeDate(date).toLowerCase()}';
}

/// Parses the many date formats the API may return.
DateTime? tryParseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final s = value.toString();
  final parsed = DateTime.tryParse(s);
  if (parsed != null) return parsed;
  try {
    return DateTime.parse(s.replaceFirst(' ', 'T'));
  } catch (_) {
    return null;
  }
}

/// Resolves possibly-localized `{en: '...'}` or plain string values.
String resolveString(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is String) return value.trim().isEmpty ? fallback : value.trim();
  if (value is Map) {
    final en = value['en'];
    if (en is String && en.trim().isNotEmpty) return en.trim();
    final fr = value['fr'];
    if (fr is String && fr.trim().isNotEmpty) return fr.trim();
  }
  return fallback;
}
