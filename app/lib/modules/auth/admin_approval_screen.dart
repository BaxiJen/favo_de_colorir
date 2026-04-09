import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../models/profile.dart';
import '../../services/profile_service.dart';

class AdminApprovalScreen extends ConsumerWidget {
  const AdminApprovalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingProfilesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Aprovar Cadastros')),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erro: $error')),
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 48, color: FavoColors.onSurfaceVariant.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text('Nenhum cadastro pendente!',
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(pendingProfilesProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: profiles.length,
              itemBuilder: (context, index) =>
                  _PendingCard(profile: profiles[index]),
            ),
          );
        },
      ),
    );
  }
}

class _PendingCard extends ConsumerWidget {
  final Profile profile;

  const _PendingCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              CircleAvatar(
                radius: 22,
                backgroundColor: FavoColors.primaryContainer.withAlpha(40),
                child: Text(
                  profile.fullName.isNotEmpty
                      ? profile.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: FavoColors.primary, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(profile.email,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          if (profile.phone != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone, size: 14, color: FavoColors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(profile.phone!, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => _reject(context, ref),
                style: OutlinedButton.styleFrom(foregroundColor: FavoColors.error),
                child: const Text('Rejeitar'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () => _approve(context, ref),
                child: const Text('Aprovar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(profileServiceProvider).approveProfile(profile.id);
      ref.invalidate(pendingProfilesProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${profile.fullName} aprovada!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rejeitar cadastro?'),
        content: Text('Rejeitar ${profile.fullName}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: FavoColors.error),
            child: const Text('Rejeitar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(profileServiceProvider).rejectProfile(profile.id);
      ref.invalidate(pendingProfilesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}
