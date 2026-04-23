import 'package:flutter_test/flutter_test.dart';

import 'package:favo/models/aula.dart';
import 'package:favo/models/cobranca.dart';
import 'package:favo/models/feriado.dart';
import 'package:favo/models/profile.dart';
import 'package:favo/models/turma.dart';

/// Testes pros campos novos adicionados nas migrations 20260422000001
/// e 20260423000003: aulas.cancelled_*, cobrancas.comprovante_*,
/// profiles.bio/rejection_reason, turmas.location/address, feriados.
///
/// Vários desses foram adicionados em commits sem TDD. Este arquivo
/// cobre as invariantes básicas de parsing.
void main() {
  group('Aula cancelled fields (migration app_completo)', () {
    test('parseia cancelled_at/reason/by quando presentes', () {
      final a = Aula.fromJson({
        'id': 'a1',
        'turma_id': 't1',
        'scheduled_date': '2026-04-22',
        'start_time': '19:00:00',
        'end_time': '20:30:00',
        'status': 'cancelled',
        'notes': null,
        'cancelled_at': '2026-04-20T10:00:00Z',
        'cancellation_reason': 'Carnaval',
        'cancelled_by': 'admin-id',
        'created_at': '2026-04-01T00:00:00Z',
      });
      expect(a.isCancelled, true);
      expect(a.cancelledAt, DateTime.parse('2026-04-20T10:00:00Z'));
      expect(a.cancellationReason, 'Carnaval');
      expect(a.cancelledBy, 'admin-id');
    });

    test('aula ativa → todos os cancelled_* null', () {
      final a = Aula.fromJson({
        'id': 'a1',
        'turma_id': 't1',
        'scheduled_date': '2026-04-22',
        'start_time': '19:00:00',
        'end_time': '20:30:00',
        'status': 'scheduled',
        'created_at': '2026-04-01T00:00:00Z',
      });
      expect(a.isCancelled, false);
      expect(a.cancelledAt, isNull);
      expect(a.cancellationReason, isNull);
      expect(a.cancelledBy, isNull);
    });
  });

  group('Cobranca comprovante (migration app_completo)', () {
    test('hasComprovante true quando URL presente', () {
      final c = Cobranca.fromJson({
        'id': 'c1',
        'student_id': 's1',
        'month_year': '2026-04',
        'plan_amount': 100.0,
        'clay_amount': 20.0,
        'firing_amount': 10.0,
        'total_amount': 130.0,
        'status': 'notified',
        'comprovante_url': 'https://s.co/storage/x.jpg',
        'comprovante_uploaded_at': '2026-04-20T10:00:00Z',
        'payment_notes': 'enviou no domingo',
        'admin_confirmed': false,
        'created_at': '2026-04-01T00:00:00Z',
      });
      expect(c.hasComprovante, true);
      expect(c.comprovanteUrl, 'https://s.co/storage/x.jpg');
      expect(c.comprovanteUploadedAt,
          DateTime.parse('2026-04-20T10:00:00Z'));
      expect(c.paymentNotes, 'enviou no domingo');
    });

    test('hasComprovante false quando URL ausente', () {
      final c = Cobranca.fromJson({
        'id': 'c1',
        'student_id': 's1',
        'month_year': '2026-04',
        'plan_amount': 100.0,
        'clay_amount': 0.0,
        'firing_amount': 0.0,
        'total_amount': 100.0,
        'status': 'pending',
        'admin_confirmed': false,
        'created_at': '2026-04-01T00:00:00Z',
      });
      expect(c.hasComprovante, false);
      expect(c.comprovanteUrl, isNull);
    });
  });

  group('Profile bio/rejection_reason/onboarded_at', () {
    Map<String, dynamic> base() => {
          'id': 'u1',
          'full_name': 'Ana',
          'email': 'ana@x.com',
          'role': 'student',
          'status': 'active',
          'created_at': '2026-01-01T00:00:00Z',
          'updated_at': '2026-01-01T00:00:00Z',
        };

    test('bio null por padrão', () {
      final p = Profile.fromJson(base());
      expect(p.bio, isNull);
      expect(p.rejectionReason, isNull);
    });

    test('bio populada aparece', () {
      final p = Profile.fromJson({
        ...base(),
        'bio': 'Modelagem desde 2020',
      });
      expect(p.bio, 'Modelagem desde 2020');
    });

    test('rejection_reason usado quando rejeitada', () {
      final p = Profile.fromJson({
        ...base(),
        'status': 'blocked',
        'rejection_reason': 'cadastro duplicado',
      });
      expect(p.rejectionReason, 'cadastro duplicado');
    });

    test('notification prefs getters com fallback true', () {
      // Sem notification_preferences = todos habilitados
      final p = Profile.fromJson(base());
      expect(p.pushEnabled, true);
      expect(p.emailEnabled, true);
      expect(p.communityNotifications, true);
    });

    test('notification prefs respeita valores explícitos', () {
      final p = Profile.fromJson({
        ...base(),
        'notification_preferences': {
          'push': false,
          'email': true,
          'community': false,
        },
      });
      expect(p.pushEnabled, false);
      expect(p.emailEnabled, true);
      expect(p.communityNotifications, false);
    });

    test('copyWith preserva id/email e muda campos selecionados', () {
      final p1 = Profile.fromJson({
        ...base(),
        'bio': 'v1',
      });
      final p2 = p1.copyWith(bio: 'v2', fullName: 'Ana Silva');
      expect(p2.id, p1.id);
      expect(p2.email, p1.email);
      expect(p2.bio, 'v2');
      expect(p2.fullName, 'Ana Silva');
    });
  });

  group('Turma location/address (migration turma_location)', () {
    Map<String, dynamic> base() => {
          'id': 't1',
          'name': 'Seg 19h',
          'modality': 'regular',
          'day_of_week': 1,
          'start_time': '19:00:00',
          'end_time': '20:30:00',
          'capacity': 8,
          'is_active': true,
          'created_at': '2026-01-01T00:00:00Z',
        };

    test('location/address null por padrão', () {
      final t = Turma.fromJson(base());
      expect(t.location, isNull);
      expect(t.address, isNull);
    });

    test('ambos populados aparecem em toJson', () {
      final t = Turma.fromJson({
        ...base(),
        'location': 'Sala 2 · bancada azul',
        'address': 'Rua Uruguai 200',
      });
      expect(t.location, 'Sala 2 · bancada azul');
      expect(t.address, 'Rua Uruguai 200');
      expect(t.toJson()['location'], 'Sala 2 · bancada azul');
      expect(t.toJson()['address'], 'Rua Uruguai 200');
    });
  });

  group('Feriado model (migration feriados)', () {
    test('parseia seed nacional', () {
      final f = Feriado.fromJson({
        'id': 'f1',
        'date': '2026-12-25',
        'name': 'Natal',
        'description': null,
        'created_by': null,
        'created_at': '2026-04-22T00:00:00Z',
      });
      expect(f.name, 'Natal');
      expect(f.date, DateTime.parse('2026-12-25'));
      expect(f.createdBy, isNull);
    });

    test('toJson omite id/created_at/created_by pra INSERT', () {
      final f = Feriado(
        id: 'f1',
        date: DateTime(2026, 7, 20),
        name: 'Aniversário do ateliê',
        createdAt: DateTime.now(),
      );
      final j = f.toJson();
      expect(j.containsKey('id'), false);
      expect(j.containsKey('created_at'), false);
      expect(j['date'], '2026-07-20');
      expect(j['name'], 'Aniversário do ateliê');
    });
  });
}
