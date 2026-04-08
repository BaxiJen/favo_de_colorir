import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../services/reposition_service.dart';

class RepositionScreen extends ConsumerWidget {
  const RepositionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repositionsAsync = ref.watch(myRepositionsProvider);
    final availableAsync = ref.watch(availableTurmasProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Repor Aula'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Turmas com Vaga'),
              Tab(text: 'Minhas Reposições'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: turmas disponíveis
            availableAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (turmas) {
                if (turmas.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64, color: FavoColors.warmGray),
                        SizedBox(height: 16),
                        Text('Nenhuma turma com vaga no momento'),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: turmas.length,
                  itemBuilder: (context, index) {
                    final item = turmas[index];
                    return _AvailableTurmaCard(item: item);
                  },
                );
              },
            ),

            // Tab 2: minhas reposições
            repositionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (repos) {
                if (repos.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma reposição solicitada'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: repos.length,
                  itemBuilder: (context, index) {
                    final repo = repos[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: Icon(
                          _statusIcon(repo.status),
                          color: _statusColor(repo.status),
                        ),
                        title: Text(repo.turmaName ?? 'Aula'),
                        subtitle: Text(
                          '${repo.originalDate != null ? DateFormat('dd/MM').format(repo.originalDate!) : ''} · ${repo.status}',
                        ),
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
      'pending' => FavoColors.honey,
      'scheduled' => FavoColors.success,
      'completed' => FavoColors.warmGray,
      'expired' => FavoColors.error,
      _ => FavoColors.warmGray,
    };
  }
}

class _AvailableTurmaCard extends ConsumerWidget {
  final TurmaWithAvailability item;

  const _AvailableTurmaCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.turma.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Chip(
                  label: Text(
                    '${item.available} vaga${item.available > 1 ? 's' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  backgroundColor: FavoColors.honeyLight,
                ),
              ],
            ),
            Text(
              '${item.turma.startTime.substring(0, 5)} – ${item.turma.endTime.substring(0, 5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Próximas aulas:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            ...item.nextAulas.map((aula) {
              final dateStr = DateFormat('EEEE, d/MM', 'pt_BR')
                  .format(aula.scheduledDate);
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(dateStr)),
                    TextButton(
                      onPressed: () => _requestReposition(
                        context,
                        ref,
                        aula.id,
                      ),
                      child: const Text('Agendar'),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _requestReposition(
    BuildContext context,
    WidgetRef ref,
    String makeupAulaId,
  ) async {
    final userId = SupabaseConfig.auth.currentUser!.id;
    final service = ref.read(repositionServiceProvider);

    // Verificar limite
    final canRequest = await service.canRequest(userId);
    if (!canRequest) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você já usou sua reposição deste mês.'),
          ),
        );
      }
      return;
    }

    try {
      // TODO: pegar original_aula_id da falta — por agora usa placeholder
      // Em produção, o fluxo começa quando a aluna declina uma aula
      await service.requestReposition(
        studentId: userId,
        originalAulaId: makeupAulaId, // será substituído pelo fluxo correto
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
