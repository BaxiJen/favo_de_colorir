import 'package:flutter/material.dart';

/// Parse de string de hora ('HH:MM:SS' ou 'HH:MM') vinda do Postgres
/// (tipo `time`) pra `TimeOfDay` usado pelos pickers.
///
/// Não valida agressivamente — assume input correto vindo do banco
/// (schema tem CHECK em start_time/end_time via tipo). Mas cuida de
/// casos de borda comuns (string vazia, segundos omitidos).
TimeOfDay parseTimeOfDay(String s) {
  if (s.isEmpty) return const TimeOfDay(hour: 0, minute: 0);
  final parts = s.split(':');
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
}

/// Inverso: TimeOfDay → 'HH:MM:SS' pra persistir em Postgres `time`.
String timeOfDayToString(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m:00';
}
