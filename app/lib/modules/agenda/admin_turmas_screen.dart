import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/turma.dart';
import '../../services/agenda_service.dart';

class AdminTurmasScreen extends ConsumerStatefulWidget {
  const AdminTurmasScreen({super.key});

  @override
  ConsumerState<AdminTurmasScreen> createState() => _AdminTurmasScreenState();
}

class _AdminTurmasScreenState extends ConsumerState<AdminTurmasScreen> {
  bool _isGenerating = false;

  static const _weekDays = [
    'Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado',
  ];

  @override
  Widget build(BuildContext context) {
    final turmasAsync = ref.watch(allTurmasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão de Turmas'),
        actions: [
          // Gerar aulas button
          IconButton(
            icon: _isGenerating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.event_repeat),
            onPressed: _isGenerating ? null : _generateAulas,
            tooltip: 'Gerar aulas (4 semanas)',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
      body: turmasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (turmas) {
          if (turmas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.class_outlined, size: 48,
                      color: FavoColors.onSurfaceVariant.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text('Nenhuma turma cadastrada',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('Crie turmas e gere as aulas automaticamente.',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(allTurmasProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: turmas.length,
              itemBuilder: (context, index) =>
                  _TurmaCard(turma: turmas[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _generateAulas() async {
    setState(() => _isGenerating = true);
    try {
      final result =
          await ref.read(agendaServiceProvider).generateAulas(weeksAhead: 4);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result['created']} aulas geradas!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    int capacity = 8;
    int? dayOfWeek;
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 11, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nova Turma'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nome'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Dia da semana'),
                  items: List.generate(7, (i) => DropdownMenuItem(
                    value: i,
                    child: Text(_weekDays[i]),
                  )),
                  onChanged: (v) => setState(() => dayOfWeek = v),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: context, initialTime: startTime);
                          if (t != null) setState(() => startTime = t);
                        },
                        child: Text('Início: ${startTime.format(context)}'),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final t = await showTimePicker(
                              context: context, initialTime: endTime);
                          if (t != null) setState(() => endTime = t);
                        },
                        child: Text('Fim: ${endTime.format(context)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Capacidade: '),
                    IconButton(
                      onPressed: () {
                        if (capacity > 1) setState(() => capacity--);
                      },
                      icon: const Icon(Icons.remove),
                    ),
                    Text('$capacity',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      onPressed: () => setState(() => capacity++),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Criar'),
            ),
          ],
        ),
      ),
    );

    if (result != true || nameCtrl.text.trim().isEmpty) return;

    try {
      final startStr =
          '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
      final endStr =
          '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

      await ref.read(agendaServiceProvider).createTurma({
        'name': nameCtrl.text.trim(),
        'modality': 'regular',
        'day_of_week': dayOfWeek,
        'start_time': startStr,
        'end_time': endStr,
        'capacity': capacity,
      });

      ref.invalidate(allTurmasProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Turma criada!')),
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

class _TurmaCard extends ConsumerWidget {
  final Turma turma;

  const _TurmaCard({required this.turma});

  static const _weekDays = [
    'Dom', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        onTap: () {
          context.push('/admin/turma-detail', extra: {
            'turmaId': turma.id,
            'turmaName': turma.name,
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: FavoColors.primaryContainer.withAlpha(30),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  turma.dayOfWeek != null ? _weekDays[turma.dayOfWeek!] : '?',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: FavoColors.primary,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(turma.name,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${turma.startTime.substring(0, 5)} – ${turma.endTime.substring(0, 5)} · ${turma.capacity} vagas',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            onPressed: () async {
              final action = await showModalBottomSheet<String>(
                context: context,
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.visibility_off),
                      title: const Text('Desativar turma'),
                      onTap: () => Navigator.pop(ctx, 'deactivate'),
                    ),
                  ],
                ),
              );
              if (action == 'deactivate' && context.mounted) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Desativar ${turma.name}?'),
                    content: const Text(
                      'A turma some das listagens e alunas matriculadas não vão mais ver aulas futuras. '
                      'Dá pra reativar depois.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FavoColors.error,
                        ),
                        child: const Text('Desativar'),
                      ),
                    ],
                  ),
                );
                if (ok != true) return;
                await ref.read(agendaServiceProvider).deactivateTurma(turma.id);
                ref.invalidate(allTurmasProvider);
              }
            },
          ),
          ],
        ),
      ),
    );
  }
}
