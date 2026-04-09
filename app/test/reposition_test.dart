import 'package:flutter_test/flutter_test.dart';

import 'package:favo/models/turma.dart';
import 'package:favo/services/reposition_service.dart';

void main() {
  group('RepositionRequest', () {
    test('fromJson parses with nested aula/turma data', () {
      final req = RepositionRequest.fromJson({
        'id': 'r-1',
        'student_id': 's-1',
        'original_aula_id': 'a-1',
        'makeup_aula_id': 'a-2',
        'month_year': '2026-04',
        'status': 'scheduled',
        'admin_override': false,
        'created_at': '2026-04-08T10:00:00Z',
        'aulas': {
          'scheduled_date': '2026-04-10',
          'turmas': {
            'name': 'Terça Manhã',
          },
        },
      });

      expect(req.id, 'r-1');
      expect(req.monthYear, '2026-04');
      expect(req.status, 'scheduled');
      expect(req.adminOverride, false);
      expect(req.turmaName, 'Terça Manhã');
      expect(req.originalDate, DateTime(2026, 4, 10));
    });

    test('fromJson handles null nested data', () {
      final req = RepositionRequest.fromJson({
        'id': 'r-2',
        'student_id': 's-1',
        'original_aula_id': 'a-1',
        'makeup_aula_id': null,
        'month_year': '2026-04',
        'status': 'pending',
        'admin_override': false,
        'created_at': '2026-04-08T10:00:00Z',
      });

      expect(req.makeupAulaId, isNull);
      expect(req.turmaName, isNull);
      expect(req.originalDate, isNull);
    });

    test('fromJson admin override', () {
      final req = RepositionRequest.fromJson({
        'id': 'r-3',
        'student_id': 's-1',
        'original_aula_id': 'a-1',
        'makeup_aula_id': 'a-3',
        'month_year': '2026-04',
        'status': 'completed',
        'admin_override': true,
        'created_at': '2026-04-08T10:00:00Z',
      });

      expect(req.adminOverride, true);
      expect(req.status, 'completed');
    });
  });

  group('TurmaWithAvailability', () {
    test('holds enrollment data', () {
      final availability = TurmaWithAvailability(
        turma: Turma(
          id: 't-1',
          name: 'Terça Manhã',
          modality: TurmaModality.regular,
          dayOfWeek: 2,
          startTime: '09:00:00',
          endTime: '11:00:00',
          capacity: 8,
          isActive: true,
          createdAt: DateTime.now(),
        ),
        enrolled: 6,
        available: 2,
        nextAulas: [],
      );

      expect(availability.enrolled, 6);
      expect(availability.available, 2);
      expect(availability.turma.name, 'Terça Manhã');
      expect(availability.nextAulas, isEmpty);
    });
  });
}
