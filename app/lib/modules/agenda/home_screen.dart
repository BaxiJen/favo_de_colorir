import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../services/agenda_service.dart';
import '../../services/auth_service.dart';
import '../../services/profile_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final nextAulaAsync = ref.watch(nextAulaProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favo de Colorir'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(authServiceProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(currentProfileProvider);
          ref.invalidate(nextAulaProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Welcome + próxima aula
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    profileAsync.when(
                      data: (profile) => Text(
                        'Bem-vinda, ${profile?.fullName.split(' ').first ?? ''}!',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      loading: () => Text(
                        'Bem-vinda!',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      error: (_, _) => Text(
                        'Bem-vinda!',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    nextAulaAsync.when(
                      data: (next) {
                        if (next == null) {
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: FavoColors.honeyLight.withAlpha(80),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_available,
                                    color: FavoColors.honey),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Sem aulas agendadas esta semana.',
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        final dateStr = DateFormat('EEEE, d/MM', 'pt_BR')
                            .format(next.aula.scheduledDate);
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: FavoColors.honeyLight.withAlpha(80),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule,
                                  color: FavoColors.honeyDark),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Próxima aula',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                    Text(
                                      '${next.turma.name} · $dateStr',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      '${next.aula.startTime.substring(0, 5)} – ${next.aula.endTime.substring(0, 5)}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Atalhos rápidos
            Text('Ações rápidas',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.swap_horiz,
                    label: 'Repor Aula',
                    color: FavoColors.honeyDark,
                    onTap: () => context.go('/agenda/reposition'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.note_add_outlined,
                    label: 'Nova Nota',
                    color: FavoColors.terracotta,
                    onTap: () => context.go('/feed'),
                  ),
                ),
              ],
            ),

            // Admin / Teacher shortcuts
            profileAsync.when(
              data: (profile) {
                if (profile == null) return const SizedBox.shrink();
                final extras = <Widget>[];

                if (profile.isAdmin) {
                  extras.addAll([
                    const SizedBox(height: 24),
                    Text('Administração',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.manage_accounts,
                            label: 'Usuários',
                            color: FavoColors.terracotta,
                            onTap: () => context.go('/admin/users'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.people,
                            label: 'Aprovar\nCadastros',
                            color: FavoColors.honey,
                            onTap: () => context.go('/admin/approvals'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.class_,
                            label: 'Turmas',
                            color: FavoColors.honeyDark,
                            onTap: () => context.go('/admin/turmas'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.attach_money,
                            label: 'Financeiro',
                            color: FavoColors.success,
                            onTap: () => context.go('/admin/billing'),
                          ),
                        ),
                      ],
                    ),
                  ]);
                }

                if (profile.isTeacher || profile.isAdmin) {
                  extras.addAll([
                    const SizedBox(height: 24),
                    Text('Professora',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    _QuickActionCard(
                      icon: Icons.dashboard,
                      label: 'Dashboard do Dia',
                      color: FavoColors.honeyDark,
                      onTap: () => context.go('/teacher/dashboard'),
                    ),
                  ]);
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: extras,
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
