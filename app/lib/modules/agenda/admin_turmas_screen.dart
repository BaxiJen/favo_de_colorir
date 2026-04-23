import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/error_handler.dart';
import '../../core/theme.dart';
import '../../core/time_parsing.dart';
import '../../models/turma.dart';
import '../../services/agenda_service.dart';

class AdminTurmasScreen extends ConsumerStatefulWidget {
  const AdminTurmasScreen({super.key});

  @override
  ConsumerState<AdminTurmasScreen> createState() => _AdminTurmasScreenState();
}

class _AdminTurmasScreenState extends ConsumerState<AdminTurmasScreen> {
  bool _isGenerating = false;

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
            tooltip: 'Gerar aulas',
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
    int weeks = 4;
    bool skipHolidays = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Gerar aulas'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quantas semanas gerar?'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [4, 8, 12, 26].map((n) {
                  return ChoiceChip(
                    label: Text('$n'),
                    selected: weeks == n,
                    onSelected: (_) => setState(() => weeks = n),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pular feriados cadastrados'),
                value: skipHolidays,
                onChanged: (v) => setState(() => skipHolidays = v ?? true),
              ),
              const SizedBox(height: 8),
              Text(
                'Gestão de feriados em Admin → Feriados.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Gerar'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    setState(() => _isGenerating = true);
    try {
      final result = await ref.read(agendaServiceProvider).generateAulas(
            weeksAhead: weeks,
            skipHolidays: skipHolidays,
          );
      if (!mounted) return;
      final created = result['created'] ?? 0;
      final skippedHoliday = result['skipped_holiday'] ?? 0;
      final skippedExisting = result['skipped_existing'] ?? 0;
      final parts = <String>['$created aulas geradas'];
      if (skippedHoliday > 0) parts.add('$skippedHoliday pulados (feriado)');
      if (skippedExisting > 0) parts.add('$skippedExisting já existiam');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parts.join(' · '))),
      );
      ref.invalidate(allTurmasProvider);
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _showCreateDialog(BuildContext context, {Turma? existing}) =>
      showTurmaFormDialog(context, ref, existing: existing);
}

Future<void> showTurmaFormDialog(
  BuildContext context,
  WidgetRef ref, {
  Turma? existing,
}) async {
  final locationCtrl = TextEditingController(text: existing?.location ?? '');
  final addressCtrl = TextEditingController(text: existing?.address ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    int capacity = existing?.capacity ?? 8;
    int? dayOfWeek = existing?.dayOfWeek;
    TimeOfDay startTime = existing != null
        ? parseTimeOfDay(existing.startTime)
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = existing != null
        ? parseTimeOfDay(existing.endTime)
        : const TimeOfDay(hour: 11, minute: 0);

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Nova Turma' : 'Editar Turma'),
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
                  initialValue: dayOfWeek,
                  decoration: const InputDecoration(labelText: 'Dia da semana'),
                  items: List.generate(7, (i) => DropdownMenuItem(
                    value: i,
                    child: Text(_weekDaysLong[i]),
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
                const SizedBox(height: 12),
                TextField(
                  controller: locationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Sala / bancada (opcional)',
                    hintText: 'Ex: Sala 2 · bancada azul',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Endereço (opcional)',
                    hintText: 'Ex: Rua Uruguai 200, Tijuca · RJ',
                  ),
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
              child: Text(existing == null ? 'Criar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );

    if (result != true || nameCtrl.text.trim().isEmpty) return;
    if (dayOfWeek == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione o dia da semana')),
        );
      }
      return;
    }

    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

    if (startStr.compareTo(endStr) >= 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Horário de término tem que ser depois do início')),
        );
      }
      return;
    }

    // Detector de conflito
    final conflict = await ref.read(agendaServiceProvider).checkScheduleConflict(
          dayOfWeek: dayOfWeek!,
          startTime: startStr,
          endTime: endStr,
          excludeTurmaId: existing?.id,
        );
    if (conflict != null && context.mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Conflito de horário'),
          content: Text(
              'Já existe "${conflict.name}" nesse mesmo dia/horário. Criar mesmo assim?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: FavoColors.error),
              child: const Text('Criar mesmo assim'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    try {
      if (existing == null) {
        await ref.read(agendaServiceProvider).createTurma({
          'name': nameCtrl.text.trim(),
          'modality': 'regular',
          'day_of_week': dayOfWeek,
          'start_time': startStr,
          'end_time': endStr,
          'capacity': capacity,
          'location': locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
          'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
        });
      } else {
        await ref.read(agendaServiceProvider).updateTurma(existing.id, {
          'name': nameCtrl.text.trim(),
          'day_of_week': dayOfWeek,
          'start_time': startStr,
          'end_time': endStr,
          'capacity': capacity,
          'location': locationCtrl.text.trim().isEmpty ? null : locationCtrl.text.trim(),
          'address': addressCtrl.text.trim().isEmpty ? null : addressCtrl.text.trim(),
        });
      }

      ref.invalidate(allTurmasProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(existing == null
                  ? 'Turma criada!'
                  : 'Turma atualizada!')),
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
}

Future<void> _showSingleAulaDialog(
    BuildContext context, WidgetRef ref, Turma turma) async {
  DateTime? date;
  TimeOfDay startTime = parseTimeOfDay(turma.startTime);
  TimeOfDay endTime = parseTimeOfDay(turma.endTime);
  final notesCtrl = TextEditingController();

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Aula pontual em ${turma.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(date == null
                    ? 'Escolher data'
                    : '${date!.day}/${date!.month}/${date!.year}'),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: ctx,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => date = d);
                },
              ),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: ctx, initialTime: startTime);
                        if (t != null) setState(() => startTime = t);
                      },
                      child: Text('Início ${startTime.format(ctx)}'),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      onPressed: () async {
                        final t = await showTimePicker(
                            context: ctx, initialTime: endTime);
                        if (t != null) setState(() => endTime = t);
                      },
                      child: Text('Fim ${endTime.format(ctx)}'),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Notas (opcional)'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agendar')),
        ],
      ),
    ),
  );

  if (ok != true || date == null) return;

  final startStr =
      '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}:00';
  final endStr =
      '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}:00';

  try {
    await ref.read(agendaServiceProvider).createSingleAula(
          turmaId: turma.id,
          date: date!,
          startTime: startStr,
          endTime: endStr,
          notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        );
    ref.invalidate(allTurmasProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aula agendada!')),
      );
    }
  } catch (e) {
    if (context.mounted) showErrorSnackBar(context, e);
  }
}

const _weekDaysLong = [
  'Domingo', 'Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado',
];


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
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Editar turma'),
                      onTap: () => Navigator.pop(ctx, 'edit'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.event_available_outlined),
                      title: const Text('Agendar aula pontual'),
                      onTap: () => Navigator.pop(ctx, 'single_aula'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.visibility_off),
                      title: const Text('Desativar turma'),
                      onTap: () => Navigator.pop(ctx, 'deactivate'),
                    ),
                  ],
                ),
              );
              if (action == 'edit' && context.mounted) {
                await showTurmaFormDialog(context, ref, existing: turma);
                return;
              }
              if (action == 'single_aula' && context.mounted) {
                await _showSingleAulaDialog(context, ref, turma);
                return;
              }
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
