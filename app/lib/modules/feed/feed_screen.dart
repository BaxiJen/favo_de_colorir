import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(
        title: const Text('Meu Feed'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context, ref),
        backgroundColor: FavoColors.honey,
        child: const Icon(Icons.add),
      ),
      body: feedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.photo_library_outlined,
                      size: 64, color: FavoColors.warmGray),
                  SizedBox(height: 16),
                  Text('Seu feed está vazio'),
                  SizedBox(height: 8),
                  Text('Adicione notas e fotos das suas peças!'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(myFeedProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: entries.length,
              itemBuilder: (context, index) {
                return _FeedEntryCard(entry: entries[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context, WidgetRef ref) async {
    final contentCtrl = TextEditingController();
    String? selectedColor;
    bool isPublic = false;

    final noteColors = [
      {'label': 'Amarelo', 'value': '#FFF9C4'},
      {'label': 'Rosa', 'value': '#F8BBD0'},
      {'label': 'Azul', 'value': '#BBDEFB'},
      {'label': 'Verde', 'value': '#C8E6C9'},
      {'label': 'Laranja', 'value': '#FFE0B2'},
    ];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nova nota'),
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
                              ? Border.all(width: 3, color: FavoColors.honey)
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
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (result != true || contentCtrl.text.trim().isEmpty) return;

    try {
      final userId = SupabaseConfig.auth.currentUser!.id;
      await ref.read(feedServiceProvider).createEntry(
        studentId: userId,
        entryType: FeedEntryType.quickNote,
        content: contentCtrl.text.trim(),
        noteColor: selectedColor,
        isPublic: isPublic,
      );

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

class _FeedEntryCard extends ConsumerWidget {
  final FeedEntry entry;

  const _FeedEntryCard({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = entry.noteColor != null
        ? Color(int.parse(entry.noteColor!.replaceFirst('#', '0xFF')))
        : null;

    return Card(
      color: bgColor,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _typeIcon(entry.entryType),
                  size: 18,
                  color: FavoColors.warmGray,
                ),
                const SizedBox(width: 8),
                Text(
                  _typeLabel(entry.entryType),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  DateFormat('dd/MM HH:mm').format(entry.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            if (entry.content != null) ...[
              const SizedBox(height: 8),
              Text(
                entry.content!,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ],

            // Photos
            if (entry.photos != null && entry.photos!.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: entry.photos!.length,
                  itemBuilder: (context, index) {
                    final photo = entry.photos![index];
                    final url = ref
                        .read(feedServiceProvider)
                        .getPhotoUrl(photo.storagePath);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 120,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Footer
            const SizedBox(height: 8),
            Row(
              children: [
                if (entry.isPublic)
                  const Chip(
                    label: Text('Publicado', style: TextStyle(fontSize: 10)),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  onPressed: () async {
                    await ref
                        .read(feedServiceProvider)
                        .deleteEntry(entry.id);
                    ref.invalidate(myFeedProvider);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _typeIcon(FeedEntryType type) {
    return switch (type) {
      FeedEntryType.classNote => Icons.school,
      FeedEntryType.pieceUpdate => Icons.palette,
      FeedEntryType.photo => Icons.photo,
      FeedEntryType.quickNote => Icons.note,
    };
  }

  String _typeLabel(FeedEntryType type) {
    return switch (type) {
      FeedEntryType.classNote => 'Nota de aula',
      FeedEntryType.pieceUpdate => 'Atualização de peça',
      FeedEntryType.photo => 'Foto',
      FeedEntryType.quickNote => 'Nota rápida',
    };
  }
}
