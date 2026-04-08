import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      (a) => a.aula.scheduledDate.isAfter(now) ||
          _isSameDay(a.aula.scheduledDate, now),
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

  const PresencaWithProfile({
    required this.presenca,
    required this.studentName,
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

      final presencas = presencasData.map((p) {
        final profileData = p['profiles'] as Map<String, dynamic>?;
        return PresencaWithProfile(
          presenca: Presenca.fromJson(p),
          studentName: profileData?['full_name'] as String? ?? '',
        );
      }).toList();

      result.add(AulaWithPresencas(aula: aula, presencas: presencas));
    }
    return result;
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
