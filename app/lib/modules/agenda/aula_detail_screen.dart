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
        title: const Text('Detalhes da Aula'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: aulasAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (aulas) {
          final item = aulas
              .where((a) => a.aula.id == widget.aulaId)
              .firstOrNull;

          if (item == null) {
            return const Center(child: Text('Aula não encontrada'));
          }

          final confirmacao = item.minhaPresenca?.confirmation;
          final dateStr = DateFormat('EEEE, d MMMM yyyy', 'pt_BR')
              .format(item.aula.scheduledDate);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Turma name
                Text(
                  item.turma.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),

                // Date
                Row(
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: FavoColors.warmGray),
                    const SizedBox(width: 8),
                    Text(dateStr,
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
                const SizedBox(height: 4),

                // Time
                Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 18, color: FavoColors.warmGray),
                    const SizedBox(width: 8),
                    Text(
                      '${item.aula.startTime.substring(0, 5)} – ${item.aula.endTime.substring(0, 5)}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),

                if (item.aula.notes != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    item.aula.notes!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                // Confirmação
                Text(
                  'Sua presença',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),

                if (confirmacao == ConfirmationStatus.confirmed)
                  _buildStatusBanner(
                    context,
                    icon: Icons.check_circle,
                    color: FavoColors.success,
                    text: 'Presença confirmada!',
                  )
                else if (confirmacao == ConfirmationStatus.declined)
                  _buildStatusBanner(
                    context,
                    icon: Icons.cancel,
                    color: FavoColors.error,
                    text: 'Você informou que não vai.',
                  )
                else ...[
                  Text(
                    'Confirme se você vai comparecer a esta aula.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                ],

                // Botões
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _handleConfirmation(false),
                        icon: const Icon(Icons.close),
                        label: const Text('Não vou'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FavoColors.error,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : () => _handleConfirmation(true),
                        icon: const Icon(Icons.check),
                        label: const Text('Vou!'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(text,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _handleConfirmation(bool going) async {
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
            content: Text(going ? 'Presença confirmada!' : 'Falta registrada.'),
          ),
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
