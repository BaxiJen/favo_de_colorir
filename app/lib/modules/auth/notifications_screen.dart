import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';

final myNotificationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) return [];
  return await SupabaseConfig.client
      .from('notifications')
      .select()
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .limit(50);
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notificações')),
      body: notifAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none,
                      size: 48, color: FavoColors.onSurfaceVariant.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text('Nenhuma notificação',
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(myNotificationsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final n = notifications[index];
                final isRead = n['read'] as bool? ?? false;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isRead
                        ? FavoColors.surfaceContainerLowest
                        : FavoColors.primaryContainer.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _typeIcon(n['type'] as String? ?? ''),
                        size: 20,
                        color: isRead
                            ? FavoColors.onSurfaceVariant
                            : FavoColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['title'] as String? ?? '',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(n['body'] as String? ?? '',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd/MM HH:mm').format(
                                  DateTime.parse(n['created_at'] as String)),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
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

  IconData _typeIcon(String type) {
    return switch (type) {
      'confirmation' => Icons.calendar_today,
      'reminder' => Icons.alarm,
      'approval' => Icons.check_circle,
      'billing' => Icons.receipt,
      'waitlist' => Icons.people,
      'general' => Icons.campaign,
      _ => Icons.notifications,
    };
  }
}
