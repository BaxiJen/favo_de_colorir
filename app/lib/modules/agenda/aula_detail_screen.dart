import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/presenca.dart';
import '../../services/agenda_service.dart';

class AulaDetailScreen extends ConsumerStatefulWidget {
  final String aulaId;

  const AulaDetailScreen({super.key, required this.aulaId});

  @override
  ConsumerState<AulaDetailScreen> createState() => _AulaDetailScreenState();
}

class _AulaDetailScreenState extends ConsumerState<AulaDetailScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final aulasAsync = ref.watch(myWeekAulasProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: aulasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (aulas) {
          final item =
              aulas.where((a) => a.aula.id == widget.aulaId).firstOrNull;

          if (item == null) {
            return const Center(child: Text('Aula não encontrada'));
          }

          final confirmacao = item.minhaPresenca?.confirmation;
          final dateStr = DateFormat('EEEE, d MMMM yyyy', 'pt_BR')
              .format(item.aula.scheduledDate);

          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              // Turma
              Text(item.turma.name,
                  style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 16),

              // Info rows
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                text: dateStr,
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.access_time,
                text:
                    '${item.aula.startTime.substring(0, 5)} – ${item.aula.endTime.substring(0, 5)}',
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.people_outline,
                text: 'Capacidade: ${item.turma.capacity} alunas',
              ),

              if (item.aula.notes != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FavoColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(item.aula.notes!,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],

              const SizedBox(height: 32),

              // Status
              Text('Sua presença',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),

              if (confirmacao == ConfirmationStatus.confirmed)
                _StatusBanner(
                  icon: Icons.check_circle,
                  color: FavoColors.success,
                  text: 'Presença confirmada!',
                )
              else if (confirmacao == ConfirmationStatus.declined)
                _StatusBanner(
                  icon: Icons.cancel,
                  color: FavoColors.error,
                  text: 'Você informou que não vai.',
                )
              else
                Text(
                  'Confirme se você vai comparecer a esta aula.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),

              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => _confirm(false),
                        child: const Text('Não Vou'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : () => _confirm(true),
                        child: const Text('Vou!'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirm(bool going) async {
    setState(() => _isLoading = true);
    try {
      final userId = SupabaseConfig.auth.currentUser!.id;
      final service = ref.read(agendaServiceProvider);
      if (going) {
        await service.confirmPresenca(widget.aulaId, userId);
      } else {
        await service.declinePresenca(widget.aulaId, userId);
      }
      ref.invalidate(myWeekAulasProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(going ? 'Presença confirmada!' : 'Falta registrada.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: FavoColors.onSurfaceVariant),
        const SizedBox(width: 10),
        Text(text, style: Theme.of(context).textTheme.bodyLarge),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(text,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                  )),
        ],
      ),
    );
  }
}
