import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/error_handler.dart';
import '../../core/theme.dart';
import '../../services/community_service.dart';

class CommunityFeedScreen extends ConsumerWidget {
  const CommunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(communityFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comunidade'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Conversas',
            onPressed: () => context.push('/chat'),
          ),
        ],
      ),
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
    XFile? selectedImage;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Nova publicação'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: ctrl,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'Compartilhe algo com o ateliê...',
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedImage != null)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: kIsWeb
                            ? Image.network(selectedImage!.path,
                                height: 120, width: double.infinity,
                                fit: BoxFit.cover)
                            : Image.file(File(selectedImage!.path),
                                height: 120, width: double.infinity,
                                fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => setState(() => selectedImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final img = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1200,
                        imageQuality: 85,
                      );
                      if (img != null) setState(() => selectedImage = img);
                    },
                    icon: const Icon(Icons.photo, size: 18),
                    label: const Text('Adicionar foto'),
                  ),
              ],
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
      ),
    );

    if (result != true) return;
    if (ctrl.text.trim().isEmpty && selectedImage == null) return;

    // Indicador "moderando..."
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      duration: Duration(seconds: 30),
      content: Row(children: [
        SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white)),
        SizedBox(width: 12),
        Text('Publicando e moderando...'),
      ]),
    ));

    try {
      List<String>? imageUrls;
      if (selectedImage != null) {
        final bytes = kIsWeb ? await selectedImage!.readAsBytes() : null;
        final url = await ref.read(communityServiceProvider).uploadPostPhoto(
              filename: selectedImage!.name,
              bytes: bytes,
              file: kIsWeb ? null : File(selectedImage!.path),
            );
        imageUrls = [url];
      }

      final result = await ref.read(communityServiceProvider).createPost(
            ctrl.text.trim().isNotEmpty ? ctrl.text.trim() : 'Foto',
            imageUrls: imageUrls,
          );
      ref.invalidate(communityFeedProvider);

      messenger.hideCurrentSnackBar();
      if (!context.mounted) return;

      if (!result.approved) {
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Publicação não aprovada'),
            content: Text(result.reason ??
                'Sua publicação não passou pela moderação. Revise e tente de novo.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        messenger.showSnackBar(
          const SnackBar(content: Text('Publicação no ar!')),
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) showErrorSnackBar(context, e);
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
              child: Image.network(
                post.imageUrls.first,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    height: 200,
                    color: FavoColors.surfaceContainerLow,
                    child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                },
                errorBuilder: (_, _, _) => Container(
                  height: 200,
                  color: FavoColors.surfaceContainerLow,
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: FavoColors.outline, size: 36),
                  ),
                ),
              ),
            ),
          ],

          if (post.moderationStatus == ModerationStatus.pending) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FavoColors.primaryContainer.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Aguardando moderação',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: FavoColors.primary,
                    ),
              ),
            ),
          ] else if (post.moderationStatus == ModerationStatus.rejected) ...[
            const SizedBox(height: 12),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FavoColors.error.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Publicação rejeitada pela moderação',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: FavoColors.error,
                    ),
              ),
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
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _CommentsSheet(postId: postId),
    );
  }
}

class _CommentsSheet extends ConsumerStatefulWidget {
  final String postId;
  const _CommentsSheet({required this.postId});

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _ctrl = TextEditingController();
  XFile? _attached;
  bool _sending = false;
  Future<List<CommunityComment>>? _commentsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _commentsFuture =
        ref.read(communityServiceProvider).getComments(widget.postId);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 82,
    );
    if (img != null) setState(() => _attached = img);
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty && _attached == null) return;
    setState(() => _sending = true);
    try {
      String? imageUrl;
      if (_attached != null) {
        final bytes = kIsWeb ? await _attached!.readAsBytes() : null;
        imageUrl = await ref.read(communityServiceProvider).uploadCommentPhoto(
              filename: _attached!.name,
              bytes: bytes,
              file: kIsWeb ? null : File(_attached!.path),
            );
      }
      await ref.read(communityServiceProvider).addComment(
            widget.postId,
            text.isEmpty ? '📷' : text,
            imageUrl: imageUrl,
          );
      _ctrl.clear();
      if (mounted) {
        setState(() {
          _attached = null;
          _reload();
        });
        ref.invalidate(communityFeedProvider);
      }
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Comentários',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: FutureBuilder<List<CommunityComment>>(
              future: _commentsFuture,
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final comments = snap.data!;
                if (comments.isEmpty) {
                  return const Center(
                      child: Text('Seja a primeira a comentar'));
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: comments.length,
                  itemBuilder: (ctx, i) => _CommentTile(c: comments[i]),
                );
              },
            ),
          ),
          if (_attached != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: kIsWeb
                        ? FutureBuilder<Uint8List>(
                            future: _attached!.readAsBytes(),
                            builder: (_, snap) {
                              if (!snap.hasData) {
                                return const SizedBox(width: 60, height: 60);
                              }
                              return Image.memory(snap.data!,
                                  width: 60, height: 60, fit: BoxFit.cover);
                            },
                          )
                        : Image.file(File(_attached!.path),
                            width: 60, height: 60, fit: BoxFit.cover),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _attached = null),
                  ),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_outlined,
                      color: FavoColors.onSurfaceVariant),
                  onPressed: _sending ? null : _pick,
                  tooltip: 'Anexar foto',
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Escreva um comentário...',
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send, color: FavoColors.primary),
                  onPressed: _sending ? null : _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final CommunityComment c;
  const _CommentTile({required this.c});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: FavoColors.primaryContainer.withAlpha(40),
            backgroundImage: c.authorAvatar != null
                ? NetworkImage(c.authorAvatar!)
                : null,
            child: c.authorAvatar == null
                ? Text(
                    c.authorName.isNotEmpty
                        ? c.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        fontSize: 12,
                        color: FavoColors.primary,
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.authorName,
                    style: Theme.of(context).textTheme.labelMedium),
                if (c.content.isNotEmpty)
                  Text(c.content,
                      style: Theme.of(context).textTheme.bodyMedium),
                if (c.imageUrl != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      c.imageUrl!,
                      width: 180,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        width: 180,
                        height: 120,
                        color: FavoColors.surfaceContainerLow,
                        child: const Icon(Icons.broken_image_outlined,
                            color: FavoColors.outline),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
