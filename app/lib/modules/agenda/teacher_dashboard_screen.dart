import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/presenca.dart';
import '../../models/turma.dart';
import '../../services/agenda_service.dart';

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherId = SupabaseConfig.auth.currentUser!.id;
    final turmasProvider = FutureProvider<List<Turma>>((ref) {
      return ref.read(agendaServiceProvider).getTeacherTurmas(teacherId);
    });
    final turmas = ref.watch(turmasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard do Dia')),
      body: turmas.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (turmaList) {
          if (turmaList.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.dashboard_outlined,
                      size: 48,
                      color: FavoColors.onSurfaceVariant.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text('Nenhuma turma atribuída',
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: turmaList.length,
            itemBuilder: (context, index) =>
                _TurmaDayCard(turma: turmaList[index]),
          );
        },
      ),
    );
  }
}

class _TurmaDayCard extends ConsumerWidget {
  final Turma turma;

  const _TurmaDayCard({required this.turma});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aulasAsync = ref.watch(turmaAulasDoDiaProvider(turma.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: FavoColors.primaryContainer.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.palette_outlined,
                    color: FavoColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(turma.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(
                      '${turma.startTime.substring(0, 5)} – ${turma.endTime.substring(0, 5)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          aulasAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) =>
                const Text('Erro ao carregar', style: TextStyle(color: FavoColors.error)),
            data: (aulasWithPresencas) {
              if (aulasWithPresencas.isEmpty) {
                return Text('Sem aula hoje',
                    style: Theme.of(context).textTheme.bodySmall);
              }

              final aula = aulasWithPresencas.first;
              final confirmed = aula.presencas
                  .where((p) =>
                      p.presenca.confirmation == ConfirmationStatus.confirmed)
                  .length;
              final declined = aula.presencas
                  .where((p) =>
                      p.presenca.confirmation == ConfirmationStatus.declined)
                  .length;
              final pending = aula.presencas.length - confirmed - declined;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Counters
                  Row(
                    children: [
                      _Counter(
                          icon: Icons.check, count: confirmed, color: FavoColors.success),
                      const SizedBox(width: 12),
                      _Counter(
                          icon: Icons.close, count: declined, color: FavoColors.error),
                      const SizedBox(width: 12),
                      _Counter(
                          icon: Icons.hourglass_empty,
                          count: pending,
                          color: FavoColors.primary),
                      const Spacer(),
                      Text(
                        '${aula.presencas.length}/${turma.capacity}',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Student list
                  ...aula.presencas.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  _confirmColor(p.presenca.confirmation)
                                      .withAlpha(30),
                              child: Icon(
                                _confirmIcon(p.presenca.confirmation),
                                size: 14,
                                color:
                                    _confirmColor(p.presenca.confirmation),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(p.studentName,
                                  style: Theme.of(context).textTheme.bodyMedium),
                            ),
                            // Botão registrar materiais
                            IconButton(
                              icon: const Icon(Icons.edit_note, size: 20),
                              color: FavoColors.primary,
                              tooltip: 'Registrar materiais',
                              onPressed: () {
                                final encoded = Uri.encodeComponent(p.studentName);
                                context.go(
                                    '/materiais/${aula.aula.id}/${p.presenca.studentId}/$encoded');
                              },
                            ),
                          ],
                        ),
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _confirmIcon(ConfirmationStatus status) {
    return switch (status) {
      ConfirmationStatus.confirmed => Icons.check,
      ConfirmationStatus.declined => Icons.close,
      ConfirmationStatus.pending => Icons.hourglass_empty,
      ConfirmationStatus.noResponse => Icons.remove,
    };
  }

  Color _confirmColor(ConfirmationStatus status) {
    return switch (status) {
      ConfirmationStatus.confirmed => FavoColors.success,
      ConfirmationStatus.declined => FavoColors.error,
      ConfirmationStatus.pending => FavoColors.primary,
      ConfirmationStatus.noResponse => FavoColors.outline,
    };
  }
}

class _Counter extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _Counter(
      {required this.icon, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
