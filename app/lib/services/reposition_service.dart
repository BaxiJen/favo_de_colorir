import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../models/aula.dart';
import '../models/turma.dart';
import 'auth_service.dart';

final repositionServiceProvider = Provider<RepositionService>((ref) {
  return RepositionService();
});

/// Reposições pendentes do aluno
final myRepositionsProvider =
    FutureProvider<List<RepositionRequest>>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (state) {
      final userId = state.session?.user.id;
      if (userId == null) return [];
      return ref.read(repositionServiceProvider).getMyRepositions(userId);
    },
    loading: () => [],
    error: (_, _) => [],
  );
});

/// Turmas com vaga disponível para reposição
final availableTurmasProvider =
    FutureProvider<List<TurmaWithAvailability>>((ref) {
  return ref.read(repositionServiceProvider).getAvailableTurmas();
});

class RepositionRequest {
  final String id;
  final String studentId;
  final String originalAulaId;
  final String? makeupAulaId;
  final String monthYear;
  final String status;
  final bool adminOverride;
  final DateTime createdAt;
  final String? turmaName;
  final DateTime? originalDate;

  const RepositionRequest({
    required this.id,
    required this.studentId,
    required this.originalAulaId,
    this.makeupAulaId,
    required this.monthYear,
    required this.status,
    required this.adminOverride,
    required this.createdAt,
    this.turmaName,
    this.originalDate,
  });

  factory RepositionRequest.fromJson(Map<String, dynamic> json) {
    final aulaData = json['aulas'] as Map<String, dynamic>?;
    final turmaData = aulaData?['turmas'] as Map<String, dynamic>?;

    return RepositionRequest(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      originalAulaId: json['original_aula_id'] as String,
      makeupAulaId: json['makeup_aula_id'] as String?,
      monthYear: json['month_year'] as String,
      status: json['status'] as String,
      adminOverride: json['admin_override'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      turmaName: turmaData?['name'] as String?,
      originalDate: aulaData?['scheduled_date'] != null
          ? DateTime.parse(aulaData!['scheduled_date'] as String)
          : null,
    );
  }
}

class TurmaWithAvailability {
  final Turma turma;
  final int enrolled;
  final int available;
  final List<Aula> nextAulas;

  const TurmaWithAvailability({
    required this.turma,
    required this.enrolled,
    required this.available,
    required this.nextAulas,
  });
}

class RepositionService {
  final _client = SupabaseConfig.client;

  Future<List<RepositionRequest>> getMyRepositions(String userId) async {
    final data = await _client
        .from('reposicoes')
        .select('*, aulas:original_aula_id(scheduled_date, turmas:turma_id(name))')
        .eq('student_id', userId)
        .order('created_at', ascending: false);

    return data.map((json) => RepositionRequest.fromJson(json)).toList();
  }

  /// Verificar se pode solicitar reposição no mês
  Future<bool> canRequest(String userId) async {
    final now = DateTime.now();
    final monthYear =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final result = await _client
        .rpc('can_request_reposition', params: {
      'p_student_id': userId,
      'p_month_year': monthYear,
    });

    return result as bool;
  }

  /// Solicitar reposição (criar registro + agendar na nova turma)
  Future<void> requestReposition({
    required String studentId,
    required String originalAulaId,
    required String makeupAulaId,
  }) async {
    final now = DateTime.now();
    final monthYear =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Criar reposição
    await _client.from('reposicoes').insert({
      'student_id': studentId,
      'original_aula_id': originalAulaId,
      'makeup_aula_id': makeupAulaId,
      'month_year': monthYear,
      'status': 'scheduled',
    });

    // Criar presença na aula de reposição
    await _client.from('presencas').upsert({
      'aula_id': makeupAulaId,
      'student_id': studentId,
      'confirmation': 'confirmed',
      'is_makeup': true,
      'confirmed_at': DateTime.now().toIso8601String(),
    });
  }

  /// Buscar turmas com vagas para reposição
  Future<List<TurmaWithAvailability>> getAvailableTurmas() async {
    final turmasData = await _client
        .from('turmas')
        .select()
        .eq('is_active', true)
        .order('day_of_week')
        .order('start_time');

    final result = <TurmaWithAvailability>[];
    final now = DateTime.now();
    final weekEnd = now.add(const Duration(days: 14));

    for (final tJson in turmasData) {
      final turma = Turma.fromJson(tJson);

      // Contar matriculados
      final enrolledData = await _client
          .from('turma_alunos')
          .select('id')
          .eq('turma_id', turma.id)
          .eq('status', 'active');
      final enrolled = enrolledData.length;
      final available = turma.capacity - enrolled;

      if (available <= 0) continue;

      // Próximas aulas
      final aulasData = await _client
          .from('aulas')
          .select()
          .eq('turma_id', turma.id)
          .eq('status', 'scheduled')
          .gte('scheduled_date', now.toIso8601String().split('T').first)
          .lte('scheduled_date', weekEnd.toIso8601String().split('T').first)
          .order('scheduled_date');

      final nextAulas =
          aulasData.map((a) => Aula.fromJson(a)).toList();

      if (nextAulas.isEmpty) continue;

      result.add(TurmaWithAvailability(
        turma: turma,
        enrolled: enrolled,
        available: available,
        nextAulas: nextAulas,
      ));
    }

    return result;
  }

  // ─── Lista de espera ──────────────────────────────

  Future<void> joinWaitlist(String turmaId, String studentId) async {
    // Pegar próxima posição
    final existing = await _client
        .from('lista_espera')
        .select('position')
        .eq('turma_id', turmaId)
        .order('position', ascending: false)
        .limit(1);

    final nextPos = existing.isEmpty ? 1 : (existing.first['position'] as int) + 1;

    await _client.from('lista_espera').insert({
      'turma_id': turmaId,
      'student_id': studentId,
      'position': nextPos,
      'status': 'waiting',
    });
  }

  Future<void> acceptWaitlistSpot(String waitlistId, String turmaId, String studentId) async {
    await _client
        .from('lista_espera')
        .update({'status': 'accepted'})
        .eq('id', waitlistId);

    // Matricular na turma
    await _client.from('turma_alunos').upsert({
      'turma_id': turmaId,
      'student_id': studentId,
      'status': 'active',
    });
  }
}
