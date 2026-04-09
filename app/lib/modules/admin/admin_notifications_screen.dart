import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';

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

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificações Gerais')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Enviar recado para todas',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'O recado aparecerá como notificação para todas as alunas ativas.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          Text('TÍTULO',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 8),
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(hintText: 'Ex: Aviso importante'),
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
              label: const Text('Enviar para Todas'),
            ),
          ),
          const SizedBox(height: 32),

          // Histórico
          Text('Últimos recados',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          _RecentNotifications(),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty || _bodyCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha título e mensagem')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Buscar todas as alunas ativas
      final profiles = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('status', 'active');

      // Criar notificação para cada uma
      final notifications = (profiles as List).map((p) => {
            'user_id': p['id'],
            'title': _titleCtrl.text.trim(),
            'body': _bodyCtrl.text.trim(),
            'type': 'general',
            'data': {},
          });

      await SupabaseConfig.client
          .from('notifications')
          .insert(notifications.toList());

      _titleCtrl.clear();
      _bodyCtrl.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Recado enviado para ${profiles.length} pessoas!')),
        );
        setState(() {});
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
