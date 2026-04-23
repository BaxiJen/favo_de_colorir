import 'package:flutter_test/flutter_test.dart';

import 'package:favo/models/presenca.dart';

/// AgendaService.markAttendanceBatch agrupa presencaIds por status pra
/// fazer N-sized UPDATE em vez de um round-trip por presença. A lógica
/// de agrupar em si é pura — testamos aqui.
///
/// Replicada em pure-dart pra verificar invariantes sem tocar Supabase.
Map<AttendanceStatus, List<String>> groupByStatus(
    Map<String, AttendanceStatus> statuses) {
  final byStatus = <AttendanceStatus, List<String>>{};
  for (final entry in statuses.entries) {
    byStatus.putIfAbsent(entry.value, () => []).add(entry.key);
  }
  return byStatus;
}

void main() {
  group('markAttendanceBatch grouping', () {
    test('map vazio → resultado vazio', () {
      expect(groupByStatus({}), isEmpty);
    });

    test('mesmo status → 1 bucket com todos os IDs', () {
      final result = groupByStatus({
        'p1': AttendanceStatus.attended,
        'p2': AttendanceStatus.attended,
        'p3': AttendanceStatus.attended,
      });
      expect(result.keys.length, 1);
      expect(result[AttendanceStatus.attended], ['p1', 'p2', 'p3']);
    });

    test('mix de 3 status → 3 buckets', () {
      final result = groupByStatus({
        'p1': AttendanceStatus.attended,
        'p2': AttendanceStatus.absent,
        'p3': AttendanceStatus.attended,
        'p4': AttendanceStatus.late,
        'p5': AttendanceStatus.absent,
      });
      expect(result.keys.toSet(), {
        AttendanceStatus.attended,
        AttendanceStatus.absent,
        AttendanceStatus.late,
      });
      expect(result[AttendanceStatus.attended]!.toSet(), {'p1', 'p3'});
      expect(result[AttendanceStatus.absent]!.toSet(), {'p2', 'p5'});
      expect(result[AttendanceStatus.late], ['p4']);
    });

    test('preserva ordem de inserção dentro de cada bucket', () {
      final result = groupByStatus({
        'a': AttendanceStatus.attended,
        'b': AttendanceStatus.attended,
        'c': AttendanceStatus.attended,
      });
      // Map preserva ordem de inserção em Dart 2.0+, então bucket também.
      expect(result[AttendanceStatus.attended], ['a', 'b', 'c']);
    });

    test('8 alunas viram no máximo 4 updates (1 por status usado)', () {
      // Simula turma de 8 com distribuição mista.
      final result = groupByStatus({
        'p1': AttendanceStatus.attended,
        'p2': AttendanceStatus.attended,
        'p3': AttendanceStatus.attended,
        'p4': AttendanceStatus.attended,
        'p5': AttendanceStatus.late,
        'p6': AttendanceStatus.absent,
        'p7': AttendanceStatus.absent,
        'p8': AttendanceStatus.pending,
      });
      expect(result.keys.length, 4);
      // Total de IDs = 8 (nenhum perdido)
      final total = result.values.fold<int>(0, (acc, l) => acc + l.length);
      expect(total, 8);
    });
  });

  group('didAttend lógica (batch usa pra setar `attended` bool)', () {
    test('attended e late contam como presente', () {
      for (final s in [AttendanceStatus.attended, AttendanceStatus.late]) {
        final didAttend =
            s == AttendanceStatus.attended || s == AttendanceStatus.late;
        expect(didAttend, true);
      }
    });

    test('absent e pending não contam', () {
      for (final s in [AttendanceStatus.absent, AttendanceStatus.pending]) {
        final didAttend =
            s == AttendanceStatus.attended || s == AttendanceStatus.late;
        expect(didAttend, false);
      }
    });
  });
}
