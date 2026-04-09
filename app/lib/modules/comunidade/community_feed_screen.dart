import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../services/community_service.dart';

class CommunityFeedScreen extends ConsumerWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(communityFeedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Comunidade')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newPost(context, ref),
        child: const Icon(Icons.edit),
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (posts) {
          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 48,
                      color: FavoColors.onSurfaceVariant.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text('A comunidade está quieta...',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('Seja a primeira a postar!',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(communityFeedProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: posts.length,
              itemBuilder: (context, index) =>
                  _PostCard(post: posts[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _newPost(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova publicação'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: 'Compartilhe algo com o ateliê...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Publicar'),
          ),
        ],
      ),
    );

    if (result != true || ctrl.text.trim().isEmpty) return;

    try {
      await ref.read(communityServiceProvider).createPost(ctrl.text.trim());
      ref.invalidate(communityFeedProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}

class _PostCard extends ConsumerWidget {
  final CommunityPost post;

  const _PostCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: FavoColors.primaryContainer.withAlpha(40),
                backgroundImage: post.authorAvatar != null
                    ? NetworkImage(post.authorAvatar!)
                    : null,
                child: post.authorAvatar == null
                    ? Text(
                        post.authorName.isNotEmpty
                            ? post.authorName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: FavoColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(
                      DateFormat('dd MMM · HH:mm', 'pt_BR')
                          .format(post.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Content
          if (post.content != null)
            Text(post.content!, style: Theme.of(context).textTheme.bodyLarge),

          // Images
          if (post.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(post.imageUrls.first,
                  height: 200, width: double.infinity, fit: BoxFit.cover),
            ),
          ],

          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await ref
                      .read(communityServiceProvider)
                      .toggleLike(post.id);
                  ref.invalidate(communityFeedProvider);
                },
                child: Row(
                  children: [
                    Icon(
                      post.likedByMe
                          ? Icons.favorite
                          : Icons.favorite_border,
                      size: 20,
                      color: post.likedByMe
                          ? FavoColors.error
                          : FavoColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text('${post.likeCount}',
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              GestureDetector(
                onTap: () => _showComments(context, ref, post.id),
                child: Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 18, color: FavoColors.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text('${post.commentCount}',
                        style: Theme.of(context).textTheme.labelMedium),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showComments(
      BuildContext context, WidgetRef ref, String postId) async {
    final commentCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Comentários',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Expanded(
              child: FutureBuilder<List<CommunityComment>>(
                future: ref.read(communityServiceProvider).getComments(postId),
                builder: (ctx, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final comments = snap.data!;
                  if (comments.isEmpty) {
                    return const Center(child: Text('Sem comentários'));
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: comments.length,
                    itemBuilder: (ctx, i) {
                      final c = comments[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  FavoColors.surfaceContainerHigh,
                              child: Text(
                                c.authorName.isNotEmpty
                                    ? c.authorName[0]
                                    : '?',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.authorName,
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .labelMedium),
                                  Text(c.content,
                                      style: Theme.of(ctx)
                                          .textTheme
                                          .bodyMedium),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 8, 16, MediaQuery.of(ctx).viewInsets.bottom + 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Escreva um comentário...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.send, color: FavoColors.primary),
                    onPressed: () async {
                      if (commentCtrl.text.trim().isEmpty) return;
                      await ref
                          .read(communityServiceProvider)
                          .addComment(postId, commentCtrl.text.trim());
                      commentCtrl.clear();
                      ref.invalidate(communityFeedProvider);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
