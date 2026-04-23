import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_handler.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/turma.dart';
import '../../services/agenda_service.dart';

enum _Target { all, turma, role }

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _isLoading = false;

  _Target _target = _Target.all;
  Turma? _selectedTurma;
  String _selectedRole = 'student';

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final turmasAsync = ref.watch(allTurmasProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recados')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Novo recado',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Segmente pra quem vai receber. Toda a turma, uma turma específica, ou um papel (professoras, estudantes, assistentes).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 20),

          Text('DESTINATÁRIOS',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Todos'),
                selected: _target == _Target.all,
                onSelected: (_) => setState(() => _target = _Target.all),
              ),
              ChoiceChip(
                label: const Text('Turma específica'),
                selected: _target == _Target.turma,
                onSelected: (_) => setState(() => _target = _Target.turma),
              ),
              ChoiceChip(
                label: const Text('Papel específico'),
                selected: _target == _Target.role,
                onSelected: (_) => setState(() => _target = _Target.role),
              ),
            ],
          ),
          if (_target == _Target.turma) ...[
            const SizedBox(height: 12),
            turmasAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text(friendlyError(e)),
              data: (turmas) {
                return DropdownButtonFormField<String>(
                  initialValue: _selectedTurma?.id,
                  decoration: const InputDecoration(labelText: 'Turma'),
                  items: turmas
                      .map((t) =>
                          DropdownMenuItem(value: t.id, child: Text(t.name)))
                      .toList(),
                  onChanged: (id) {
                    final t = turmas.firstWhere((t) => t.id == id);
                    setState(() => _selectedTurma = t);
                  },
                );
              },
            ),
          ],
          if (_target == _Target.role) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _roleChip('Estudantes', 'student'),
                _roleChip('Professoras', 'teacher'),
                _roleChip('Assistentes', 'assistant'),
                _roleChip('Admins', 'admin'),
              ],
            ),
          ],
          const SizedBox(height: 20),

          Text('TÍTULO',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration:
                const InputDecoration(hintText: 'Ex: Aviso importante'),
          ),
          const SizedBox(height: 20),

          Text('MENSAGEM',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _bodyCtrl,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: 'Escreva o recado...',
            ),
          ),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _send,
              icon: const Icon(Icons.send, size: 18),
              label: const Text('Enviar recado'),
            ),
          ),
          const SizedBox(height: 32),

          Text('Últimos recados',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _RecentNotifications(),
        ],
      ),
    );
  }

  Widget _roleChip(String label, String value) => ChoiceChip(
        label: Text(label),
        selected: _selectedRole == value,
        onSelected: (_) => setState(() => _selectedRole = value),
      );

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha título e mensagem')),
      );
      return;
    }
    if (_target == _Target.turma && _selectedTurma == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma turma')),
      );
      return;
    }

    // Confirm pra broadcasts amplos
    if (_target == _Target.all) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enviar pra todas as pessoas ativas?'),
          content: const Text(
              'Esse recado vai pra TODO MUNDO ativo no app (alunas, professoras, assistentes e admins). Tem certeza?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar pra todos'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final body = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'body': _bodyCtrl.text.trim(),
      };
      switch (_target) {
        case _Target.all:
          body['target'] = 'all';
        case _Target.turma:
          body['target'] = 'turma';
          body['turma_id'] = _selectedTurma!.id;
        case _Target.role:
          body['target'] = 'role';
          body['role'] = _selectedRole;
      }

      final response = await SupabaseConfig.client.functions.invoke(
        'enviar-recado',
        body: body,
      );

      final sent = (response.data as Map<String, dynamic>)['sent'] ?? 0;

      _titleCtrl.clear();
      _bodyCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recado enviado para $sent pessoas.')),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _RecentNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: SupabaseConfig.client
          .from('notifications')
          .select('title, body, created_at')
          .eq('type', 'general')
          .order('created_at', ascending: false)
          .limit(10),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return Text('Nenhum recado enviado',
              style: Theme.of(context).textTheme.bodySmall);
        }

        return Column(
          children: snap.data!.map((n) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: FavoColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(n['title'] as String,
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(n['body'] as String,
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
