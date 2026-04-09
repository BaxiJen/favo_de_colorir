import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../services/reposition_service.dart';

class RepositionScreen extends ConsumerWidget {
  const RepositionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availableAsync = ref.watch(availableTurmasProvider);
    final repositionsAsync = ref.watch(myRepositionsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Repor Aula'),
          bottom: TabBar(
            labelColor: FavoColors.primary,
            unselectedLabelColor: FavoColors.onSurfaceVariant,
            indicatorColor: FavoColors.primary,
            tabs: const [
              Tab(text: 'Turmas com Vaga'),
              Tab(text: 'Minhas Reposições'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1
            availableAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (turmas) {
                if (turmas.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy,
                            size: 48,
                            color: FavoColors.onSurfaceVariant.withAlpha(80)),
                        const SizedBox(height: 16),
                        Text('Nenhuma turma com vaga no momento',
                            style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: turmas.length,
                  itemBuilder: (context, index) =>
                      _TurmaCard(item: turmas[index]),
                );
              },
            ),

            // Tab 2
            repositionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (repos) {
                if (repos.isEmpty) {
                  return const Center(child: Text('Nenhuma reposição'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(24),
                  itemCount: repos.length,
                  itemBuilder: (context, index) {
                    final repo = repos[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: FavoColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(_statusIcon(repo.status),
                              color: _statusColor(repo.status), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(repo.turmaName ?? 'Aula',
                                    style: Theme.of(context).textTheme.titleSmall),
                                if (repo.originalDate != null)
                                  Text(
                                    DateFormat('dd/MM/yyyy').format(repo.originalDate!),
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(repo.status).withAlpha(20),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              repo.status.toUpperCase(),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: _statusColor(repo.status),
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _statusIcon(String status) {
    return switch (status) {
      'pending' => Icons.hourglass_empty,
      'scheduled' => Icons.check_circle,
      'completed' => Icons.done_all,
      'expired' => Icons.timer_off,
      _ => Icons.help_outline,
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'scheduled' || 'completed' => FavoColors.success,
      'expired' => FavoColors.error,
      _ => FavoColors.primary,
    };
  }
}

class _TurmaCard extends ConsumerWidget {
  final TurmaWithAvailability item;

  const _TurmaCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              Expanded(
                child: Text(item.turma.name,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: FavoColors.success.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${item.available} vaga${item.available > 1 ? 's' : ''}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: FavoColors.success,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${item.turma.startTime.substring(0, 5)} – ${item.turma.endTime.substring(0, 5)}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          ...item.nextAulas.map((aula) {
            final dateStr =
                DateFormat('EEEE, d/MM', 'pt_BR').format(aula.scheduledDate);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(dateStr,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  TextButton(
                    onPressed: () => _request(context, ref, aula.id),
                    child: const Text('Agendar'),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _request(
      BuildContext context, WidgetRef ref, String makeupAulaId) async {
    final userId = SupabaseConfig.auth.currentUser!.id;
    final service = ref.read(repositionServiceProvider);

    final canRequest = await service.canRequest(userId);
    if (!canRequest) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você já usou sua reposição deste mês.')),
        );
      }
      return;
    }

    try {
      await service.requestReposition(
        studentId: userId,
        originalAulaId: makeupAulaId,
        makeupAulaId: makeupAulaId,
      );
      ref.invalidate(myRepositionsProvider);
      ref.invalidate(availableTurmasProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reposição agendada!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}
