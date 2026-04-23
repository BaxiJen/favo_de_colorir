import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/supabase_client.dart';
import '../models/aula.dart';
import '../models/presenca.dart';
import '../models/turma.dart';

final agendaServiceProvider = Provider<AgendaService>((ref) {
  return AgendaService();
});

/// Aulas da semana para o aluno logado
final myWeekAulasProvider = FutureProvider<List<AulaWithTurma>>((ref) async {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.read(agendaServiceProvider).getMyWeekAulas(userId);
});

/// Próxima aula do aluno
final nextAulaProvider = FutureProvider<AulaWithTurma?>((ref) async {
  final aulas = await ref.watch(myWeekAulasProvider.future);
  if (aulas.isEmpty) return null;
  final now = DateTime.now();
  try {
    return aulas.firstWhere(
      (a) =>
          a.aula.status != AulaStatus.cancelled &&
          (a.aula.scheduledDate.isAfter(now) ||
              _isSameDay(a.aula.scheduledDate, now)),
    );
  } catch (_) {
    return null;
  }
});

/// Todas as turmas (para admin)
final allTurmasProvider = FutureProvider<List<Turma>>((ref) {
  return ref.read(agendaServiceProvider).getAllTurmas();
});

/// Aulas do dia de uma turma (para professora)
final turmaAulasDoDiaProvider =
    FutureProvider.family<List<AulaWithPresencas>, String>((ref, turmaId) {
  return ref.read(agendaServiceProvider).getAulasDoDia(turmaId);
});

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class AulaWithTurma {
  final Aula aula;
  final Turma turma;
  final Presenca? minhaPresenca;

  const AulaWithTurma({
    required this.aula,
    required this.turma,
    this.minhaPresenca,
  });
}

class AulaWithPresencas {
  final Aula aula;
  final List<PresencaWithProfile> presencas;

  const AulaWithPresencas({required this.aula, required this.presencas});
}

class PresencaWithProfile {
  final Presenca presenca;
  final String studentName;
  /// Se essa presença é reposição (is_makeup=true), nome da turma original.
  final String? makeupFromTurmaName;
  /// Data da aula original da qual veio a reposição (pra mostrar "de 15/04").
  final DateTime? makeupFromDate;

  const PresencaWithProfile({
    required this.presenca,
    required this.studentName,
    this.makeupFromTurmaName,
    this.makeupFromDate,
  });
}

class AgendaService {
  final _client = SupabaseConfig.client;

  /// Busca aulas da semana do aluno (via turma_alunos)
  Future<List<AulaWithTurma>> getMyWeekAulas(String userId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    // Buscar turmas do aluno
    final enrollments = await _client
        .from('turma_alunos')
        .select('turma_id')
        .eq('student_id', userId)
        .eq('status', 'active');

    if (enrollments.isEmpty) return [];

    final turmaIds =
        enrollments.map((e) => e['turma_id'] as String).toList();

    // Buscar aulas dessas turmas na semana
    final aulasData = await _client
        .from('aulas')
        .select('*, turmas(*)')
        .inFilter('turma_id', turmaIds)
        .gte('scheduled_date', startOfWeek.toIso8601String().split('T').first)
        .lte('scheduled_date', endOfWeek.toIso8601String().split('T').first)
        .order('scheduled_date')
        .order('start_time');

    // Buscar presenças do aluno para essas aulas
    final aulaIds =
        aulasData.map((a) => a['id'] as String).toList();

    List<Map<String, dynamic>> presencasData = [];
    if (aulaIds.isNotEmpty) {
      presencasData = await _client
          .from('presencas')
          .select()
          .eq('student_id', userId)
          .inFilter('aula_id', aulaIds);
    }

    final presencasByAula = <String, Presenca>{};
    for (final p in presencasData) {
      presencasByAula[p['aula_id'] as String] = Presenca.fromJson(p);
    }

    return aulasData.map((data) {
      final aula = Aula.fromJson(data);
      final turma = Turma.fromJson(data['turmas'] as Map<String, dynamic>);
      return AulaWithTurma(
        aula: aula,
        turma: turma,
        minhaPresenca: presencasByAula[aula.id],
      );
    }).toList();
  }

  /// Confirmar presença ("Vou")
  Future<void> confirmPresenca(String aulaId, String studentId) async {
    await _client.from('presencas').upsert({
      'aula_id': aulaId,
      'student_id': studentId,
      'confirmation': 'confirmed',
      'confirmed_at': DateTime.now().toIso8601String(),
    });
  }

  /// Declinar presença ("Não vou")
  Future<void> declinePresenca(String aulaId, String studentId) async {
    await _client.from('presencas').upsert({
      'aula_id': aulaId,
      'student_id': studentId,
      'confirmation': 'declined',
      'confirmed_at': DateTime.now().toIso8601String(),
    });
  }

  // ─── Admin / Professora ──────────────────────────────

  Future<List<Turma>> getAllTurmas() async {
    final data = await _client
        .from('turmas')
        .select()
        .eq('is_active', true)
        .order('day_of_week')
        .order('start_time');
    return data.map((json) => Turma.fromJson(json)).toList();
  }

  Future<Turma> createTurma(Map<String, dynamic> turmaData) async {
    final data = await _client
        .from('turmas')
        .insert(turmaData)
        .select()
        .single();
    return Turma.fromJson(data);
  }

  Future<void> updateTurma(String id, Map<String, dynamic> updates) async {
    await _client.from('turmas').update(updates).eq('id', id);
  }

  Future<void> deactivateTurma(String id) async {
    await updateTurma(id, {'is_active': false});
    try {
      final actorId = SupabaseConfig.auth.currentUser?.id;
      await _client.from('audit_logs').insert({
        'actor_id': actorId,
        'action': 'deactivate_turma',
        'resource_type': 'turma',
        'resource_id': id,
      });
    } catch (_) {}
  }

  Future<Aula> createAula(Map<String, dynamic> aulaData) async {
    final data = await _client
        .from('aulas')
        .insert(aulaData)
        .select()
        .single();
    return Aula.fromJson(data);
  }

  /// Aulas do dia para uma turma (dashboard professora)
  Future<List<AulaWithPresencas>> getAulasDoDia(String turmaId) async {
    final today = DateTime.now().toIso8601String().split('T').first;

    final aulasData = await _client
        .from('aulas')
        .select()
        .eq('turma_id', turmaId)
        .eq('scheduled_date', today);

    if (aulasData.isEmpty) return [];

    final result = <AulaWithPresencas>[];
    for (final aulaJson in aulasData) {
      final aula = Aula.fromJson(aulaJson);
      final presencasData = await _client
          .from('presencas')
          .select('*, profiles:student_id(full_name)')
          .eq('aula_id', aula.id);

      // Pra presencas makeup: fetch info da turma/aula originais
      final makeupPresencaIds = presencasData
          .where((p) => p['is_makeup'] == true)
          .map((p) => p['student_id'] as String)
          .toList();

      final Map<String, Map<String, dynamic>> makeupInfo = {};
      if (makeupPresencaIds.isNotEmpty) {
        final repData = await _client
            .from('reposicoes')
            .select(
                '*, original_aula:original_aula_id(scheduled_date, turma:turma_id(name))')
            .eq('makeup_aula_id', aula.id)
            .inFilter('student_id', makeupPresencaIds);
        for (final r in repData) {
          final studentId = r['student_id'] as String;
          final orig = r['original_aula'] as Map<String, dynamic>?;
          final turma = orig?['turma'] as Map<String, dynamic>?;
          makeupInfo[studentId] = {
            'turma_name': turma?['name'] as String?,
            'date': orig?['scheduled_date'] as String?,
          };
        }
      }

      final presencas = presencasData.map((p) {
        final profileData = p['profiles'] as Map<String, dynamic>?;
        final info = makeupInfo[p['student_id']];
        return PresencaWithProfile(
          presenca: Presenca.fromJson(p),
          studentName: profileData?['full_name'] as String? ?? '',
          makeupFromTurmaName: info?['turma_name'] as String?,
          makeupFromDate: info?['date'] != null
              ? DateTime.parse(info!['date'] as String)
              : null,
        );
      }).toList();

      result.add(AulaWithPresencas(aula: aula, presencas: presencas));
    }
    return result;
  }

  /// Cancela uma aula (por feriado, imprevisto, etc.).
  ///
  /// Cascata:
  /// 1. aula.status = cancelled + cancelled_at + reason + cancelled_by
  /// 2. presencas dessa aula: attendance_status = absent
  /// 3. pra cada presença `confirmed`, cria reposição pending (crédito)
  /// 4. registra em audit_logs
  /// 5. cria notifications pra todos os alunos da aula
  Future<Map<String, dynamic>> cancelAula({
    required String aulaId,
    required String reason,
  }) async {
    final actorId = SupabaseConfig.auth.currentUser?.id;

    // 1. Marca aula como cancelada
    await _client.from('aulas').update({
      'status': 'cancelled',
      'cancelled_at': DateTime.now().toIso8601String(),
      'cancellation_reason': reason,
      'cancelled_by': actorId,
    }).eq('id', aulaId);

    // 2. Busca presencas (precisa dos dados pra notificar e criar reposição)
    final presencas = await _client
        .from('presencas')
        .select('id, student_id, confirmation')
        .eq('aula_id', aulaId);

    int creditsCreated = 0;
    final monthYear = DateFormat('yyyy-MM').format(DateTime.now());
    final notifications = <Map<String, dynamic>>[];

    for (final p in presencas) {
      // marca como absent
      await _client.from('presencas').update({
        'attendance_status': 'absent',
      }).eq('id', p['id']);

      final studentId = p['student_id'] as String;
      final wasConfirmed = p['confirmation'] == 'confirmed';

      if (wasConfirmed) {
        // cria crédito de reposição pra quem tinha confirmado
        try {
          await _client.from('reposicoes').insert({
            'student_id': studentId,
            'original_aula_id': aulaId,
            'month_year': monthYear,
            'status': 'pending',
            'admin_override': true,
          });
          creditsCreated++;
        } catch (_) {}
      }

      notifications.add({
        'user_id': studentId,
        'title': 'Aula cancelada',
        'body': reason.isEmpty
            ? 'Uma aula foi cancelada. Confira sua agenda.'
            : 'Aula cancelada: $reason',
        'type': 'aula_cancelled',
        'data': {'aula_id': aulaId},
      });
    }

    if (notifications.isNotEmpty) {
      await _client.from('notifications').insert(notifications);
    }

    // audit
    try {
      await _client.from('audit_logs').insert({
        'actor_id': actorId,
        'action': 'cancel_aula',
        'resource_type': 'aula',
        'resource_id': aulaId,
        'changes': {
          'reason': reason,
          'credits_created': creditsCreated,
          'notified': notifications.length,
        },
      });
    } catch (_) {}

    return {
      'credits_created': creditsCreated,
      'notified': notifications.length,
    };
  }

  /// Chamada: marca attendance_status de uma presença. Se a presença for
  /// reposição (is_makeup=true) e o status for attended/late, também
  /// completa a reposição associada automaticamente.
  Future<void> markAttendance({
    required String presencaId,
    required AttendanceStatus status,
  }) async {
    final didAttend = status == AttendanceStatus.attended ||
        status == AttendanceStatus.late;

    await _client.from('presencas').update({
      'attendance_status': Presenca.attendanceToString(status),
      'attended': didAttend,
    }).eq('id', presencaId);

    // Se era reposição e compareceu, marca reposicoes.status=completed
    if (didAttend) {
      try {
        final presenca = await _client
            .from('presencas')
            .select('aula_id, student_id, is_makeup')
            .eq('id', presencaId)
            .single();
        if (presenca['is_makeup'] == true) {
          await _client
              .from('reposicoes')
              .update({'status': 'completed'})
              .eq('makeup_aula_id', presenca['aula_id'])
              .eq('student_id', presenca['student_id']);
        }
      } catch (_) {}
    }
  }

  /// Bulk: marca todas as presenças de uma aula como ausentes
  /// (atalho: "todos faltaram" = feriado não previsto).
  Future<void> markAllAbsent(String aulaId) async {
    await _client.from('presencas').update({
      'attendance_status': 'absent',
      'attended': false,
    }).eq('aula_id', aulaId);
  }

  /// Matricular aluna em turma
  Future<void> enrollStudent(String turmaId, String studentId) async {
    await _client.from('turma_alunos').upsert({
      'turma_id': turmaId,
      'student_id': studentId,
      'status': 'active',
    });
  }

  /// Remover aluna de turma
  Future<void> unenrollStudent(String turmaId, String studentId) async {
    await _client
        .from('turma_alunos')
        .update({'status': 'inactive'})
        .eq('turma_id', turmaId)
        .eq('student_id', studentId);
  }

  /// Buscar alunos matriculados em uma turma
  Future<List<Map<String, dynamic>>> getTurmaStudents(String turmaId) async {
    return await _client
        .from('turma_alunos')
        .select('*, profiles:student_id(full_name, email, avatar_url)')
        .eq('turma_id', turmaId)
        .eq('status', 'active');
  }

  /// Gerar aulas recorrentes (chama edge function)
  Future<Map<String, dynamic>> generateAulas({
    int weeksAhead = 4,
    bool skipHolidays = true,
  }) async {
    final response = await _client.functions.invoke(
      'gerar-aulas',
      body: {
        'weeks_ahead': weeksAhead,
        'skip_holidays': skipHolidays,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  /// Buscar turmas do professor
  Future<List<Turma>> getTeacherTurmas(String teacherId) async {
    final data = await _client
        .from('turmas')
        .select()
        .eq('teacher_id', teacherId)
        .eq('is_active', true)
        .order('day_of_week')
        .order('start_time');
    return data.map((json) => Turma.fromJson(json)).toList();
  }
}
