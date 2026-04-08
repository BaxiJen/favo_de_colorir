import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../models/presenca.dart';
import '../../services/agenda_service.dart';

class MyAgendaScreen extends ConsumerWidget {
  const MyAgendaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aulasAsync = ref.watch(myWeekAulasProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Agenda'),
      ),
      body: aulasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (aulas) {
          if (aulas.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: FavoColors.warmGray),
                  SizedBox(height: 16),
                  Text('Nenhuma aula esta semana'),
                ],
              ),
            );
          }

          // Agrupar por dia
          final grouped = <String, List<AulaWithTurma>>{};
          for (final item in aulas) {
            final key = DateFormat('EEEE, d/MM', 'pt_BR')
                .format(item.aula.scheduledDate);
            (grouped[key] ??= []).add(item);
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(myWeekAulasProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final day = grouped.keys.elementAt(index);
                final dayAulas = grouped[day]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        day,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: FavoColors.honeyDark,
                            ),
                      ),
                    ),
                    ...dayAulas.map(
                      (item) => _AulaCard(item: item),
                    ),
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AulaCard extends StatelessWidget {
  final AulaWithTurma item;

  const _AulaCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final confirmacao = item.minhaPresenca?.confirmation;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => context.go('/agenda/aula/${item.aula.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Horário
              Column(
                children: [
                  Text(
                    item.aula.startTime.substring(0, 5),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    item.aula.endTime.substring(0, 5),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(
                width: 3,
                height: 40,
                decoration: BoxDecoration(
                  color: _statusColor(confirmacao),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.turma.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _statusText(confirmacao),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _statusColor(confirmacao),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: FavoColors.warmGray,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(ConfirmationStatus? status) {
    return switch (status) {
      ConfirmationStatus.confirmed => FavoColors.success,
      ConfirmationStatus.declined => FavoColors.error,
      ConfirmationStatus.pending || null => FavoColors.honey,
      ConfirmationStatus.noResponse => FavoColors.warmGray,
    };
  }

  String _statusText(ConfirmationStatus? status) {
    return switch (status) {
      ConfirmationStatus.confirmed => 'Presença confirmada',
      ConfirmationStatus.declined => 'Não vai',
      ConfirmationStatus.pending || null => 'Aguardando confirmação',
      ConfirmationStatus.noResponse => 'Sem resposta',
    };
  }
}
