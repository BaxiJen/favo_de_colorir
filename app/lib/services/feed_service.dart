import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../models/feed_entry.dart';

final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService();
});

final myFeedProvider = FutureProvider<List<FeedEntry>>((ref) async {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.read(feedServiceProvider).getMyFeed(userId);
});

class FeedService {
  final _client = SupabaseConfig.client;

  Future<List<FeedEntry>> getMyFeed(String userId, {int limit = 50, int offset = 0}) async {
    final data = await _client
        .from('feed_entries')
        .select('*, feed_photos(*)')
        .eq('student_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return data.map((json) => FeedEntry.fromJson(json)).toList();
  }

  Future<FeedEntry> createEntry({
    required String studentId,
    required FeedEntryType entryType,
    String? content,
    String? noteColor,
    String? aulaId,
    String? pecaId,
    bool isPublic = false,
  }) async {
    final data = await _client.from('feed_entries').insert({
      'student_id': studentId,
      'entry_type': _entryTypeToString(entryType),
      'content': content,
      'note_color': noteColor,
      'aula_id': aulaId,
      'peca_id': pecaId,
      'is_public': isPublic,
    }).select('*, feed_photos(*)').single();

    return FeedEntry.fromJson(data);
  }

  Future<void> updateEntry(String entryId, Map<String, dynamic> updates) async {
    await _client.from('feed_entries').update(updates).eq('id', entryId);
  }

  Future<void> deleteEntry(String entryId) async {
    await _client.from('feed_entries').delete().eq('id', entryId);
  }

  Future<void> togglePublic(String entryId, bool isPublic) async {
    await updateEntry(entryId, {'is_public': isPublic});
  }

  /// Upload de foto para o feed
  Future<FeedPhoto> uploadPhoto({
    required String feedEntryId,
    required File file,
    String? caption,
    required int sortOrder,
  }) async {
    final ext = file.path.split('.').last;
    final userId = SupabaseConfig.auth.currentUser!.id;
    final path = '$userId/$feedEntryId/${sortOrder}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await SupabaseConfig.storage
        .from('feed')
        .upload(path, file);

    final data = await _client.from('feed_photos').insert({
      'feed_entry_id': feedEntryId,
      'storage_path': path,
      'caption': caption,
      'sort_order': sortOrder,
    }).select().single();

    return FeedPhoto.fromJson(data);
  }

  /// URL pública de uma foto do feed
  String getPhotoUrl(String storagePath) {
    return SupabaseConfig.storage.from('feed').getPublicUrl(storagePath);
  }

  String _entryTypeToString(FeedEntryType t) {
    return switch (t) {
      FeedEntryType.classNote => 'class_note',
      FeedEntryType.pieceUpdate => 'piece_update',
      FeedEntryType.photo => 'photo',
      FeedEntryType.quickNote => 'quick_note',
    };
  }
}
