import 'package:flutter_test/flutter_test.dart';

import 'package:favo/models/presenca.dart';

void main() {
  group('AttendanceStatus', () {
    test('parse dos 4 valores', () {
      expect(
        Presenca.fromJson(_base(status: 'pending')).attendanceStatus,
        AttendanceStatus.pending,
      );
      expect(
        Presenca.fromJson(_base(status: 'attended')).attendanceStatus,
        AttendanceStatus.attended,
      );
      expect(
        Presenca.fromJson(_base(status: 'absent')).attendanceStatus,
        AttendanceStatus.absent,
      );
      expect(
        Presenca.fromJson(_base(status: 'late')).attendanceStatus,
        AttendanceStatus.late,
      );
    });

    test('default é pending quando ausente no JSON', () {
      final json = _base(status: null);
      json.remove('attendance_status');
      expect(
        Presenca.fromJson(json).attendanceStatus,
        AttendanceStatus.pending,
      );
    });

    test('didAttend é true para attended e late', () {
      expect(_build(AttendanceStatus.attended).didAttend, true);
      expect(_build(AttendanceStatus.late).didAttend, true);
      expect(_build(AttendanceStatus.absent).didAttend, false);
      expect(_build(AttendanceStatus.pending).didAttend, false);
    });

    test('toJson roundtrip preserva attendance_status', () {
      final p = _build(AttendanceStatus.late);
      expect(p.toJson()['attendance_status'], 'late');
    });

    test('counters: contar presentes/faltantes/pendentes', () {
      final lista = [
        _build(AttendanceStatus.attended),
        _build(AttendanceStatus.attended),
        _build(AttendanceStatus.late),
        _build(AttendanceStatus.absent),
        _build(AttendanceStatus.pending),
      ];

      final presentes =
          lista.where((p) => p.didAttend).length; // attended + late
      final faltantes =
          lista.where((p) => p.attendanceStatus == AttendanceStatus.absent).length;
      final pendentes = lista
          .where((p) => p.attendanceStatus == AttendanceStatus.pending)
          .length;

      expect(presentes, 3);
      expect(faltantes, 1);
      expect(pendentes, 1);
    });
  });
}

Map<String, dynamic> _base({required String? status}) => {
      'id': 'p-1',
      'aula_id': 'a-1',
      'student_id': 's-1',
      'confirmation': 'confirmed',
      'attendance_status': ?status,
      'is_makeup': false,
      'created_at': '2026-04-22T10:00:00Z',
    };

Presenca _build(AttendanceStatus s) => Presenca(
      id: 'p-1',
      aulaId: 'a-1',
      studentId: 's-1',
      confirmation: ConfirmationStatus.confirmed,
      attendanceStatus: s,
      isMakeup: false,
      createdAt: DateTime.parse('2026-04-22T10:00:00Z'),
    );
