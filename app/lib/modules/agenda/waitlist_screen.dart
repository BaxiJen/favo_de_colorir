import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/error_handler.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../services/reposition_service.dart';

const _weekDays = ['Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb'];

final _fullTurmasProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.read(repositionServiceProvider).getFullTurmas(userId);
});

final _myWaitlistProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.read(repositionServiceProvider).getMyWaitlist(userId);
});

/// Lista de espera vista pela aluna: minhas posições + turmas cheias.
class WaitlistScreen extends ConsumerWidget {
  const WaitlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fullAsync = ref.watch(_fullTurmasProvider);
    final myAsync = ref.watch(_myWaitlistProvider);
    final userId = SupabaseConfig.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Lista de espera')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_fullTurmasProvider);
          ref.invalidate(_myWaitlistProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Minhas filas',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            myAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyError(e)),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Você não tá em nenhuma fila agora.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: list
                      .map((entry) => _MyFilaTile(
                            entry: entry,
                            onLeave: () async {
                              final ok = await _confirm(
                                context,
                                title: 'Sair da fila?',
                                body:
                                    'Você perde a posição. Dá pra entrar de novo depois.',
                              );
                              if (!ok) return;
                              try {
                                await ref
                                    .read(repositionServiceProvider)
                                    .leaveWaitlist(entry['id'] as String);
                                ref.invalidate(_myWaitlistProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  showErrorSnackBar(context, e);
                                }
                              }
                            },
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Text('Turmas cheias',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Entre na fila e te avisamos quando abrir vaga.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            fullAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyError(e)),
              data: (list) {
                if (list.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      'Todas as turmas têm vaga no momento.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return Column(
                  children: list
                      .map((t) => _FullTurmaTile(
                            turma: t,
                            onJoin: userId == null
                                ? null
                                : () async {
                                    try {
                                      await ref
                                          .read(repositionServiceProvider)
                                          .joinWaitlist(
                                              t['id'] as String, userId);
                                      ref.invalidate(_fullTurmasProvider);
                                      ref.invalidate(_myWaitlistProvider);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Pronto, você entrou na fila. Avisamos quando abrir vaga.'),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        showErrorSnackBar(context, e);
                                      }
                                    }
                                  },
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MyFilaTile extends ConsumerWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onLeave;

  const _MyFilaTile({required this.entry, required this.onLeave});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final turma = entry['turmas'] as Map<String, dynamic>?;
    final status = entry['status'] as String;
    final position = entry['position'] as int;
    final canAccept = status == 'notified';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: canAccept
            ? FavoColors.success.withAlpha(25)
            : FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: canAccept
            ? Border.all(color: FavoColors.success, width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: FavoColors.primaryContainer.withAlpha(40),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text('#$position',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: FavoColors.primary,
                          fontWeight: FontWeight.w700,
                        )),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(turma?['name'] as String? ?? 'Turma',
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      canAccept
                          ? 'Vaga disponível — pode aceitar agora!'
                          : 'Aguardando abrir vaga',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: canAccept ? FavoColors.success : null,
                            fontWeight:
                                canAccept ? FontWeight.w600 : FontWeight.normal,
                          ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.exit_to_app, size: 20),
                color: FavoColors.error,
                tooltip: 'Sair da fila',
                onPressed: onLeave,
              ),
            ],
          ),
          if (canAccept) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () async {
                final userId = SupabaseConfig.auth.currentUser?.id;
                if (userId == null) return;
                try {
                  await ref.read(repositionServiceProvider).acceptWaitlistSpot(
                        entry['id'] as String,
                        entry['turma_id'] as String,
                        userId,
                      );
                  ref.invalidate(_myWaitlistProvider);
                  ref.invalidate(_fullTurmasProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Pronto! Você tá matriculada na turma. Bem-vinda.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) showErrorSnackBar(context, e);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: FavoColors.success),
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Aceitar vaga'),
            ),
          ],
        ],
      ),
    );
  }
}

class _FullTurmaTile extends StatelessWidget {
  final Map<String, dynamic> turma;
  final VoidCallback? onJoin;

  const _FullTurmaTile({required this.turma, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    final day = turma['day_of_week'] as int?;
    final start = (turma['start_time'] as String?)?.substring(0, 5) ?? '';
    final end = (turma['end_time'] as String?)?.substring(0, 5) ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: FavoColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(day != null ? _weekDays[day] : '?',
                style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(turma['name'] as String,
                    style: Theme.of(context).textTheme.titleSmall),
                Text('$start – $end',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onJoin,
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
  }
}

/// Vista do admin/teacher: fila de uma turma específica.
class AdminWaitlistScreen extends ConsumerWidget {
  final String turmaId;
  final String turmaName;
  const AdminWaitlistScreen({
    super.key,
    required this.turmaId,
    required this.turmaName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(_turmaWaitlistProvider(turmaId));

    return Scaffold(
      appBar: AppBar(title: Text('Fila · $turmaName')),
      body: listAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Fila vazia.'),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, i) {
              final entry = list[i];
              final profile = entry['profiles'] as Map<String, dynamic>?;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: FavoColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          FavoColors.primaryContainer.withAlpha(40),
                      child: Text('#${entry['position']}',
                          style: const TextStyle(
                            color: FavoColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile?['full_name'] as String? ?? '',
                              style:
                                  Theme.of(context).textTheme.titleSmall),
                          Text(
                            '${entry['status']} · desde ${DateFormat('dd/MM').format(DateTime.parse(entry['created_at'] as String))}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (entry['status'] == 'waiting' ||
                        entry['status'] == 'notified')
                      OutlinedButton(
                        onPressed: () async {
                          final ok = await _confirm(
                            context,
                            title: 'Promover manualmente?',
                            body:
                                '${profile?['full_name']} vira matriculada em $turmaName agora.',
                          );
                          if (!ok) return;
                          try {
                            await ref
                                .read(repositionServiceProvider)
                                .acceptWaitlistSpot(
                                  entry['id'] as String,
                                  turmaId,
                                  entry['student_id'] as String,
                                );
                            ref.invalidate(
                                _turmaWaitlistProvider(turmaId));
                          } catch (e) {
                            if (context.mounted) {
                              showErrorSnackBar(context, e);
                            }
                          }
                        },
                        child: const Text('Promover'),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

final _turmaWaitlistProvider = FutureProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, turmaId) {
  return ref.read(repositionServiceProvider).getWaitlistForTurma(turmaId);
});

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;
}
