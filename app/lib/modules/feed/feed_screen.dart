import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/supabase_client.dart';
import '../../core/theme.dart';
import '../../models/feed_entry.dart';
import '../../services/feed_service.dart';

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(myFeedProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Meu Feed',
                      style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  Text(
                    'A história das suas criações, peça por peça.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: feedAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Erro: $e')),
                data: (entries) {
                  if (entries.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 48,
                              color: FavoColors.onSurfaceVariant
                                  .withAlpha(80)),
                          const SizedBox(height: 16),
                          Text('Seu feed está vazio',
                              style:
                                  Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Adicione notas e fotos das suas peças!',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(myFeedProvider.future),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: entries.length,
                      itemBuilder: (context, index) =>
                          _FeedCard(entry: entries[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final contentCtrl = TextEditingController();
    String? selectedColor;
    bool isPublic = false;
    final List<XFile> selectedPhotos = [];

    final noteColors = [
      {'label': 'Amarelo', 'value': '#FFF9C4'},
      {'label': 'Rosa', 'value': '#F8BBD0'},
      {'label': 'Azul', 'value': '#BBDEFB'},
      {'label': 'Verde', 'value': '#C8E6C9'},
      {'label': 'Laranja', 'value': '#FFE0B2'},
    ];

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
                  controller: contentCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Escreva sobre sua peça, sua aula...',
                  ),
                ),
                const SizedBox(height: 16),

                // Photo picker
                if (selectedPhotos.isNotEmpty) ...[
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedPhotos.length,
                      itemBuilder: (ctx, i) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? Image.network(selectedPhotos[i].path,
                                      width: 80, height: 80, fit: BoxFit.cover)
                                  : Image.file(File(selectedPhotos[i].path),
                                      width: 80, height: 80, fit: BoxFit.cover),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => selectedPhotos.removeAt(i)),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close,
                                      size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picker = ImagePicker();
                        final images = await picker.pickMultiImage(
                          maxWidth: 1200,
                          imageQuality: 85,
                        );
                        if (images.isNotEmpty) {
                          setState(() => selectedPhotos.addAll(images));
                        }
                      },
                      icon: const Icon(Icons.photo_library, size: 18),
                      label: const Text('Galeria'),
                    ),
                    const SizedBox(width: 8),
                    if (!kIsWeb)
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picker = ImagePicker();
                          final photo = await picker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 1200,
                            imageQuality: 85,
                          );
                          if (photo != null) {
                            setState(() => selectedPhotos.add(photo));
                          }
                        },
                        icon: const Icon(Icons.camera_alt, size: 18),
                        label: const Text('Câmera'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // Color picker
                Wrap(
                  spacing: 8,
                  children: noteColors.map((c) {
                    final color = Color(
                        int.parse(c['value']!.replaceFirst('#', '0xFF')));
                    final isSelected = selectedColor == c['value'];
                    return GestureDetector(
                      onTap: () =>
                          setState(() => selectedColor = c['value']),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  width: 3, color: FavoColors.primary)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: isPublic,
                  onChanged: (v) => setState(() => isPublic = v),
                  title: const Text('Publicar na comunidade'),
                  dense: true,
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
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;
    if (contentCtrl.text.trim().isEmpty && selectedPhotos.isEmpty) return;

    try {
      final userId = SupabaseConfig.auth.currentUser!.id;
      final entryType = selectedPhotos.isNotEmpty
          ? FeedEntryType.photo
          : FeedEntryType.quickNote;

      final entry = await ref.read(feedServiceProvider).createEntry(
        studentId: userId,
        entryType: entryType,
        content: contentCtrl.text.trim().isNotEmpty
            ? contentCtrl.text.trim()
            : null,
        noteColor: selectedColor,
        isPublic: isPublic,
      );

      // Upload photos
      for (var i = 0; i < selectedPhotos.length; i++) {
        final file = File(selectedPhotos[i].path);
        await ref.read(feedServiceProvider).uploadPhoto(
          feedEntryId: entry.id,
          file: file,
          sortOrder: i,
        );
      }

      ref.invalidate(myFeedProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}

class _FeedCard extends ConsumerWidget {
  final FeedEntry entry;

  const _FeedCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photos
          if (entry.photos != null && entry.photos!.isNotEmpty)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  ref
                      .read(feedServiceProvider)
                      .getPhotoUrl(entry.photos!.first.storagePath),
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: FavoColors.surfaceContainerLow,
                      child: const Center(
                          child:
                              CircularProgressIndicator(strokeWidth: 2)),
                    );
                  },
                  errorBuilder: (_, _, _) => Container(
                    color: FavoColors.surfaceContainerLow,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: FavoColors.outline, size: 36),
                    ),
                  ),
                ),
              ),
            ),

          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (entry.content != null) ...[
                  Text(
                    _truncateTitle(entry.content!),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (entry.content!.length > 40) ...[
                    const SizedBox(height: 8),
                    Text(
                      entry.content!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy', 'pt_BR')
                          .format(entry.createdAt),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (entry.isPublic) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: FavoColors.primary.withAlpha(15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Público',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: FavoColors.primary)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _truncateTitle(String content) {
    final firstLine = content.split('\n').first;
    return firstLine.length > 40 ? firstLine.substring(0, 40) : firstLine;
  }
}
