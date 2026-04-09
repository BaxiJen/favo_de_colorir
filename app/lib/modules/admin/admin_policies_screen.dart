import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../services/policy_service.dart';

class AdminPoliciesScreen extends ConsumerWidget {
  const AdminPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policiesAsync = ref.watch(activePoliciesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Políticas do Ateliê'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _forceReaccept(context, ref),
            tooltip: 'Forçar re-aceite de todas',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addPolicy(context, ref),
        child: const Icon(Icons.add),
      ),
      body: policiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (policies) {
          if (policies.isEmpty) {
            return const Center(child: Text('Nenhuma política cadastrada'));
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(activePoliciesProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: policies.length,
              itemBuilder: (context, index) {
                final policy = policies[index];
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
                          Expanded(
                            child: Text(policy.title,
                                style: Theme.of(context).textTheme.titleMedium),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: FavoColors.primary.withAlpha(15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('v${policy.version}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: FavoColors.primary)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(policy.content,
                          style: Theme.of(context).textTheme.bodyMedium),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () =>
                                _editPolicy(context, ref, policy),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Editar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _editPolicy(
      BuildContext context, WidgetRef ref, Policy policy) async {
    final titleCtrl = TextEditingController(text: policy.title);
    final contentCtrl = TextEditingController(text: policy.content);

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Política'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Conteúdo'),
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
              child: const Text('Salvar')),
        ],
      ),
    );

    if (result != true) return;

    try {
      await SupabaseConfig.client.from('policies').update({
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'version': policy.version + 1,
      }).eq('id', policy.id);

      ref.invalidate(activePoliciesProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Política atualizada!')),
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

  Future<void> _addPolicy(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova Política'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Título'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentCtrl,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Conteúdo'),
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
              child: const Text('Criar')),
        ],
      ),
    );

    if (result != true || titleCtrl.text.trim().isEmpty) return;

    try {
      await SupabaseConfig.client.from('policies').insert({
        'title': titleCtrl.text.trim(),
        'content': contentCtrl.text.trim(),
        'version': 1,
      });
      ref.invalidate(activePoliciesProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _forceReaccept(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forçar re-aceite?'),
        content: const Text(
          'Todas as alunas terão que aceitar as políticas novamente no próximo login.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Deletar todos os aceites — forçar re-aceite
      await SupabaseConfig.client
          .from('policy_acceptances')
          .delete()
          .neq('user_id', '00000000-0000-0000-0000-000000000000');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Re-aceite forçado! Todas as alunas precisarão aceitar novamente.')),
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
