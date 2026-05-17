import 'package:dose_vault/core/models/medication.dart';
import 'package:intl/intl.dart';

String fmt(String t) {
  try {
    final p = t.split(':');
    final d = DateTime(2000, 1, 1, int.parse(p[0]), int.parse(p[1]));
    return DateFormat('h:mm a').format(d);
  } catch (_) {
    return t;
  }
}

String dosageLabel(Medication m) {
  final d = m.dosage.truncateToDouble() == m.dosage
      ? m.dosage.toInt().toString()
      : m.dosage.toString();
  return '$d${m.unit} • Tablet';
}