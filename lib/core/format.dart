import 'package:intl/intl.dart';

/// Utilidades de formato (espejo de src/utils/format.ts del app RN).
/// - Moneda MXN con separador de miles y 2 decimales: $9,324,282.24
/// - Fecha DD/MM/YYYY.

final _mxn = NumberFormat.currency(locale: 'en_US', symbol: r'$', decimalDigits: 2);

/// 9324282.24 -> "$9,324,282.24"
String formatMXN(num? amount) {
  if (amount == null || amount.isNaN) return r'$0.00';
  return _mxn.format(amount);
}

/// 2459159 -> "$2.46M"
String formatMXNCompact(num? amount) {
  final n = (amount ?? 0).toDouble();
  final abs = n.abs();
  if (abs >= 1000000) return '\$${(n / 1000000).toStringAsFixed(2)}M';
  if (abs >= 1000) return '\$${(n / 1000).toStringAsFixed(0)}K';
  return '\$${n.toStringAsFixed(0)}';
}

/// Date/ISO string -> "DD/MM/YYYY". Null/inválida -> "—".
String formatDate(Object? input) {
  if (input == null) return '—';
  DateTime? d;
  if (input is DateTime) {
    d = input;
  } else if (input is String && input.isNotEmpty) {
    d = DateTime.tryParse(input);
  }
  if (d == null) return '—';
  return DateFormat('dd/MM/yyyy').format(d);
}

/// Meses cortos en español (formato es-MX del portal).
const _mesesCortoEs = <String>[
  'ene', 'feb', 'mar', 'abr', 'may', 'jun',
  'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
];

/// Date/ISO string -> "11 feb 2026" (formato es-MX del portal: día a 2 dígitos,
/// mes corto en minúsculas, año). Null/inválida -> "—".
String formatDateEsMX(Object? input) {
  DateTime? d;
  if (input is DateTime) {
    d = input;
  } else if (input is String && input.isNotEmpty) {
    d = DateTime.tryParse(input);
  }
  if (d == null) return '—';
  final dd = d.day.toString().padLeft(2, '0');
  return '$dd ${_mesesCortoEs[d.month - 1]} ${d.year}';
}

/// "Juan Pérez López" -> "JP"
String initials(String? name) {
  if (name == null || name.trim().isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  final a = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '';
  final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
  final r = (a + b).toUpperCase();
  return r.isEmpty ? '?' : r;
}
