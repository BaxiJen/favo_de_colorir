import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/presenca.dart';
import '../../services/agenda_service.dart';
import '../../services/profile_service.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final nextAulaAsync = ref.watch(nextAulaProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(currentProfileProvider);
            ref.invalidate(nextAulaProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FavoColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.local_florist,
                        color: FavoColors.onPrimary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text('Artisanal Studio',
                      style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    onPressed: () => context.push('/notifications'),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Greeting
              profileAsync.when(
                data: (profile) {
                  final firstName =
                      profile?.fullName.split(' ').first ?? '';
                  return RichText(
                    text: TextSpan(
                      style: Theme.of(context).textTheme.headlineLarge,
                      children: [
                        const TextSpan(text: 'Olá, '),
                        TextSpan(
                          text: '$firstName.',
                          style: const TextStyle(
                            color: FavoColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => Text('Olá!',
                    style: Theme.of(context).textTheme.headlineLarge),
                error: (_, _) => Text('Olá!',
                    style: Theme.of(context).textTheme.headlineLarge),
              ),
              const SizedBox(height: 4),
              Text(
                'Seu refúgio criativo está pronto para hoje.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),

              // Próxima aula card
              nextAulaAsync.when(
                data: (next) {
                  if (next == null) {
                    return _EmptyAulaCard();
                  }
                  return _NextAulaCard(item: next);
                },
                loading: () => Container(
                  height: 160,
                  decoration: BoxDecoration(
                    color: FavoColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child:
                      const Center(child: CircularProgressIndicator()),
                ),
                error: (_, _) => _EmptyAulaCard(),
              ),
              const SizedBox(height: 20),

              // Quick actions
              Row(
                children: [
                  Expanded(
                    child: _ActionChip(
                      icon: Icons.swap_horiz,
                      label: 'Repor Aula',
                      onTap: () => context.go('/agenda/reposition'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionChip(
                      icon: Icons.history,
                      label: 'Histórico',
                      onTap: () => context.go('/feed'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Admin section
              profileAsync.when(
                data: (profile) {
                  if (profile == null) return const SizedBox.shrink();
                  if (!profile.isAdmin && !profile.isTeacher) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (profile.isAdmin) ...[
                        Text('Administração',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        _buildAdminGrid(context),
                        const SizedBox(height: 20),
                      ],
                      if (profile.isTeacher || profile.isAdmin) ...[
                        _ActionChip(
                          icon: Icons.dashboard_outlined,
                          label: 'Dashboard do Dia',
                          onTap: () => context.push('/teacher/dashboard'),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdminGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.4,
      children: [
        _AdminCard(
          icon: Icons.manage_accounts,
          label: 'Usuários',
          onTap: () => context.push('/admin/users'),
        ),
        _AdminCard(
          icon: Icons.people_outline,
          label: 'Cadastros',
          onTap: () => context.push('/admin/approvals'),
        ),
        _AdminCard(
          icon: Icons.class_outlined,
          label: 'Turmas',
          onTap: () => context.push('/admin/turmas'),
        ),
        _AdminCard(
          icon: Icons.attach_money,
          label: 'Financeiro',
          onTap: () => context.push('/admin/billing'),
        ),
        _AdminCard(
          icon: Icons.person_add,
          label: 'Criar Aluna',
          onTap: () => context.push('/admin/create-user'),
        ),
        _AdminCard(
          icon: Icons.settings,
          label: 'Preços',
          onTap: () => context.push('/admin/config'),
        ),
        _AdminCard(
          icon: Icons.forum,
          label: 'Comunidade',
          onTap: () => context.push('/community'),
        ),
        _AdminCard(
          icon: Icons.inventory_2,
          label: 'Estoque',
          onTap: () => context.push('/stock'),
        ),
        _AdminCard(
          icon: Icons.description,
          label: 'Políticas',
          onTap: () => context.push('/admin/policies'),
        ),
        _AdminCard(
          icon: Icons.campaign,
          label: 'Recados',
          onTap: () => context.push('/admin/notifications'),
        ),
      ],
    );
  }
}

class _NextAulaCard extends ConsumerWidget {
  final AulaWithTurma item;

  const _NextAulaCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final confirmation = item.minhaPresenca?.confirmation;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('PRÓXIMA AULA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.5,
                        color: FavoColors.onSurfaceVariant,
                      )),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: FavoColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Hoje',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: FavoColors.onPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            item.turma.name,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time,
                  size: 16, color: FavoColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '${item.aula.startTime.substring(0, 5)} – ${item.aula.endTime.substring(0, 5)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              Icon(Icons.people_outline,
                  size: 16, color: FavoColors.onSurfaceVariant),
              const SizedBox(width: 4),
              Text('${item.turma.capacity}',
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    onPressed: confirmation == ConfirmationStatus.confirmed
                        ? null
                        : () async {
                            final userId = SupabaseConfig.auth.currentUser!.id;
                            await ref.read(agendaServiceProvider)
                                .confirmPresenca(item.aula.id, userId);
                            ref.invalidate(myWeekAulasProvider);
                            ref.invalidate(nextAulaProvider);
                          },
                    child: const Text('Vou'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: confirmation == ConfirmationStatus.declined
                        ? null
                        : () async {
                            final userId = SupabaseConfig.auth.currentUser!.id;
                            await ref.read(agendaServiceProvider)
                                .declinePresenca(item.aula.id, userId);
                            ref.invalidate(myWeekAulasProvider);
                            ref.invalidate(nextAulaProvider);
                          },
                    child: const Text('Não Vou'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyAulaCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_available,
              size: 40, color: FavoColors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text('Sem aulas agendadas esta semana.',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: FavoColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: FavoColors.primary),
            const SizedBox(width: 8),
            Text(label, style: Theme.of(context).textTheme.labelLarge),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FavoColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: FavoColors.primary),
            const SizedBox(height: 6),
            Text(label,
                style: Theme.of(context).textTheme.labelSmall,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
