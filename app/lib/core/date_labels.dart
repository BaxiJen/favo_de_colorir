import 'package:intl/intl.dart';

/// Label humano pra diferença entre `date` e `ref` (default `now`).
///
/// - Mesmo dia → "Hoje"
/// - Amanhã → "Amanhã"
/// - Daqui a 2–6 dias → nome do dia em PT-BR maiúsculo ("TERÇA-FEIRA")
/// - Resto → dd/MM
///
/// Usa só a data (ignora horário) — comparar 23h com 01h do dia seguinte
/// retorna "Amanhã", não "daqui 2h".
String whenLabel(DateTime date, {DateTime? ref}) {
  final now = ref ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(date.year, date.month, date.day);
  final diff = d.difference(today).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Amanhã';
  if (diff > 1 && diff < 7) {
    return DateFormat('EEEE', 'pt_BR').format(d).toUpperCase();
  }
  return DateFormat('dd/MM').format(d);
}
