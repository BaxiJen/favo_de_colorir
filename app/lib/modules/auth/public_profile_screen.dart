import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/error_handler.dart';
import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/peca.dart';
import '../../models/peca_foto.dart';
import '../../models/profile.dart';
import '../../services/material_service.dart';
import '../../services/profile_service.dart';

final _publicProfileProvider =
    FutureProvider.family<Profile?, String>((ref, userId) {
  return ref.read(profileServiceProvider).getProfile(userId);
});

final _userPiecesProvider =
    FutureProvider.family<List<Peca>, String>((ref, userId) {
  return ref.read(materialServiceProvider).getStudentPieces(userId);
});

/// Perfil público de outra aluna/aluno — visualização, não edição.
class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_publicProfileProvider(userId));
    final piecesAsync = ref.watch(_userPiecesProvider(userId));
    final isMe = SupabaseConfig.auth.currentUser?.id == userId;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(friendlyError(e))),
        data: (p) {
          if (p == null) {
            return const Center(child: Text('Perfil não encontrado.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              // Header
              Center(
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: FavoColors.primaryContainer.withAlpha(40),
                  backgroundImage: p.avatarUrl != null
                      ? NetworkImage(p.avatarUrl!)
                      : null,
                  child: p.avatarUrl == null
                      ? Text(
                          p.fullName.isNotEmpty
                              ? p.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 36,
                            color: FavoColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(p.fullName,
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(_roleLabel(p.role),
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              if (p.bio != null && p.bio!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: FavoColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(p.bio!,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ],
              if (!isMe) ...[
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push(
                      '/chat/${p.id}',
                      extra: {
                        'peerName': p.fullName,
                        'peerAvatar': p.avatarUrl,
                      },
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Mandar mensagem'),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Text('Peças',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              piecesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(friendlyError(e)),
                data: (pieces) {
                  if (pieces.isEmpty) {
                    return Text('Ainda não há peças registradas.',
                        style: Theme.of(context).textTheme.bodyMedium);
                  }
                  return Column(
                    children: pieces
                        .map((peca) => _PecaTile(peca: peca))
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  String _roleLabel(UserRole r) => switch (r) {
        UserRole.admin => 'Administradora',
        UserRole.teacher => 'Professora',
        UserRole.assistant => 'Assistente',
        UserRole.student => 'Estudante',
      };
}

class _PecaTile extends ConsumerWidget {
  final Peca peca;
  const _PecaTile({required this.peca});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fotos = ref.watch(_pecaFotosProvider(peca.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(_stageLabel(peca.stage),
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              Text(
                DateFormat('dd/MM').format(peca.createdAt),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (peca.notes != null && peca.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(peca.notes!,
                style: Theme.of(context).textTheme.bodySmall),
          ],
          fotos.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (_, i) {
                      final foto = list[i];
                      final url = ref
                          .read(materialServiceProvider)
                          .getPecaPhotoUrl(foto.storagePath);
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          url,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            width: 80,
                            height: 80,
                            color: FavoColors.surfaceContainerLow,
                            child: const Icon(Icons.broken_image_outlined,
                                color: FavoColors.outline, size: 18),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _stageLabel(PecaStage s) => switch (s) {
        PecaStage.modeled => 'Modelou',
        PecaStage.painted => 'Pintou',
        PecaStage.bisqueFired => 'Queima de biscoito',
        PecaStage.glazeFired => 'Queima de esmalte',
      };
}

final _pecaFotosProvider =
    FutureProvider.family<List<PecaFoto>, String>((ref, pecaId) {
  return ref.read(materialServiceProvider).getPecaPhotos(pecaId);
});
