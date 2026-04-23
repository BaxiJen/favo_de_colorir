import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';

final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});

final communityFeedProvider = FutureProvider<List<CommunityPost>>((ref) {
  return ref.read(communityServiceProvider).getFeed();
});

enum ModerationStatus { pending, approved, rejected }

class CommunityPost {
  final String id;
  final String authorId;
  final String? content;
  final List<String> imageUrls;
  final bool isFlagged;
  final ModerationStatus moderationStatus;
  final DateTime createdAt;
  final String authorName;
  final String? authorAvatar;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  const CommunityPost({
    required this.id,
    required this.authorId,
    this.content,
    required this.imageUrls,
    required this.isFlagged,
    this.moderationStatus = ModerationStatus.approved,
    required this.createdAt,
    required this.authorName,
    this.authorAvatar,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });
}

class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String content;
  final String? imageUrl;
  final DateTime createdAt;
  final String authorName;
  final String? authorAvatar;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    this.imageUrl,
    required this.createdAt,
    required this.authorName,
    this.authorAvatar,
  });
}

class ModerationResult {
  final bool approved;
  final String? reason;
  const ModerationResult({required this.approved, this.reason});
}

class ChatConversation {
  final String peerId;
  final String peerName;
  final String? peerAvatar;
  final String lastMessage;
  final DateTime lastAt;
  final int unreadCount;

  const ChatConversation({
    required this.peerId,
    required this.peerName,
    this.peerAvatar,
    required this.lastMessage,
    required this.lastAt,
    required this.unreadCount,
  });
}

class ChatMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String content;
  final String? imageUrl;
  final DateTime? readAt;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.imageUrl,
    this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['content'] as String,
      imageUrl: json['image_url'] as String?,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class CommunityService {
  final _client = SupabaseConfig.client;

  Future<List<CommunityPost>> getFeed({int limit = 50}) async {
    final userId = SupabaseConfig.auth.currentUser?.id;

    // RLS já filtra: outros usuários só veem approved; autor vê os próprios pendentes/rejeitados.
    final data = await _client
        .from('community_posts')
        .select('*, profiles:author_id(full_name, avatar_url)')
        .eq('is_flagged', false)
        .order('created_at', ascending: false)
        .limit(limit);

    if (data.isEmpty) return [];

    final postIds = data.map((r) => r['id'] as String).toList();

    // Batch: todos os likes e comments de uma vez (2 queries, não N*2)
    final allLikes = await _client
        .from('community_likes')
        .select('post_id, user_id')
        .inFilter('post_id', postIds);

    final allComments = await _client
        .from('community_comments')
        .select('post_id')
        .inFilter('post_id', postIds);

    // Agrupar por post
    final likesByPost = <String, List<Map<String, dynamic>>>{};
    for (final l in allLikes) {
      (likesByPost[l['post_id'] as String] ??= []).add(l);
    }

    final commentCountByPost = <String, int>{};
    for (final c in allComments) {
      final pid = c['post_id'] as String;
      commentCountByPost[pid] = (commentCountByPost[pid] ?? 0) + 1;
    }

    return data.map((row) {
      final postId = row['id'] as String;
      final profile = row['profiles'] as Map<String, dynamic>?;
      final postLikes = likesByPost[postId] ?? [];

      return CommunityPost(
        id: postId,
        authorId: row['author_id'] as String,
        content: row['content'] as String?,
        imageUrls: (row['image_urls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        isFlagged: row['is_flagged'] as bool,
        moderationStatus: _parseModeration(row['moderation_status'] as String?),
        createdAt: DateTime.parse(row['created_at'] as String),
        authorName: profile?['full_name'] as String? ?? '',
        authorAvatar: profile?['avatar_url'] as String?,
        likeCount: postLikes.length,
        commentCount: commentCountByPost[postId] ?? 0,
        likedByMe: postLikes.any((l) => l['user_id'] == userId),
      );
    }).toList();
  }

  /// Cria post moderado. Fluxo síncrono:
  /// 1. insere com moderation_status=pending (outros usuários não veem)
  /// 2. chama edge function moderar-post e aguarda
  /// 3. se aprovado, muda status pra approved; se não, pra rejected
  ///
  /// Retorna [ModerationResult] pra tela reagir.
  Future<ModerationResult> createPost(
    String content, {
    List<String>? imageUrls,
  }) async {
    final data = await _client.from('community_posts').insert({
      'author_id': SupabaseConfig.auth.currentUser!.id,
      'content': content,
      'image_urls': imageUrls ?? [],
      'moderation_status': 'pending',
    }).select('id').single();

    final postId = data['id'] as String;

    try {
      final response = await _client.functions.invoke(
        'moderar-post',
        body: {'post_id': postId, 'content': content},
      );
      final body = response.data as Map<String, dynamic>?;
      final approved = (body?['approved'] as bool?) ?? true;
      final reason = body?['reason'] as String?;

      await _client.from('community_posts').update({
        'moderation_status': approved ? 'approved' : 'rejected',
        'is_flagged': !approved,
        'flag_reason': reason,
      }).eq('id', postId);

      return ModerationResult(approved: approved, reason: reason);
    } catch (_) {
      // Edge function caiu? Deixa passar (fail-open) pra não travar a pessoa.
      await _client.from('community_posts').update({
        'moderation_status': 'approved',
      }).eq('id', postId);
      return const ModerationResult(approved: true);
    }
  }

  /// Upload de foto pro bucket posts (comunidade). Retorna URL pública.
  Future<String> uploadPostPhoto({
    required String filename,
    Uint8List? bytes,
    File? file,
  }) async {
    final userId = SupabaseConfig.auth.currentUser!.id;
    final ext = filename.split('.').last.toLowerCase();
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = _client.storage.from('posts');
    if (bytes != null) {
      await storage.uploadBinary(path, bytes);
    } else {
      await storage.upload(path, file!);
    }
    return storage.getPublicUrl(path);
  }

  Future<void> toggleLike(String postId) async {
    final userId = SupabaseConfig.auth.currentUser!.id;

    final existing = await _client
        .from('community_likes')
        .select('id')
        .eq('post_id', postId)
        .eq('user_id', userId)
        .maybeSingle();

    if (existing != null) {
      await _client
          .from('community_likes')
          .delete()
          .eq('id', existing['id']);
    } else {
      await _client.from('community_likes').insert({
        'post_id': postId,
        'user_id': userId,
      });
    }
  }

  Future<List<CommunityComment>> getComments(String postId) async {
    final data = await _client
        .from('community_comments')
        .select('*, profiles:author_id(full_name, avatar_url)')
        .eq('post_id', postId)
        .order('created_at');

    return data.map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      return CommunityComment(
        id: row['id'] as String,
        postId: row['post_id'] as String,
        authorId: row['author_id'] as String,
        content: row['content'] as String,
        imageUrl: row['image_url'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
        authorName: profile?['full_name'] as String? ?? '',
        authorAvatar: profile?['avatar_url'] as String?,
      );
    }).toList();
  }

  Future<void> addComment(
    String postId,
    String content, {
    String? imageUrl,
  }) async {
    await _client.from('community_comments').insert({
      'post_id': postId,
      'author_id': SupabaseConfig.auth.currentUser!.id,
      'content': content,
      'image_url': imageUrl,
    });
  }

  /// Upload de foto anexada a comentário — bucket posts (mesmo dos posts).
  Future<String> uploadCommentPhoto({
    required String filename,
    Uint8List? bytes,
    File? file,
  }) async {
    return uploadPostPhoto(filename: filename, bytes: bytes, file: file);
  }

  Future<void> deletePost(String postId) async {
    await _client.from('community_posts').delete().eq('id', postId);
  }

  Future<void> flagPost(String postId, String reason) async {
    await _client.from('community_posts').update({
      'is_flagged': true,
      'flag_reason': reason,
    }).eq('id', postId);
  }

  // ─── Chat ──────────────────────────────

  Future<List<ChatMessage>> getMessages(String peerId) async {
    final userId = SupabaseConfig.auth.currentUser!.id;

    final data = await _client
        .from('chat_messages')
        .select()
        .or('and(sender_id.eq.$userId,receiver_id.eq.$peerId),and(sender_id.eq.$peerId,receiver_id.eq.$userId)')
        .order('created_at');

    return data.map((row) => ChatMessage.fromJson(row)).toList();
  }

  Future<void> sendMessage(
    String receiverId,
    String content, {
    String? imageUrl,
  }) async {
    await _client.from('chat_messages').insert({
      'sender_id': SupabaseConfig.auth.currentUser!.id,
      'receiver_id': receiverId,
      'content': content,
      'image_url': imageUrl,
    });
  }

  /// Upload de foto pro chat (bucket chat, privado).
  Future<String> uploadChatPhoto({
    required String filename,
    Uint8List? bytes,
    File? file,
  }) async {
    final userId = SupabaseConfig.auth.currentUser!.id;
    final ext = filename.split('.').last.toLowerCase();
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final storage = _client.storage.from('chat');
    if (bytes != null) {
      await storage.uploadBinary(path, bytes);
    } else {
      await storage.upload(path, file!);
    }
    // bucket chat é privado — signed url de 7 dias
    return await storage.createSignedUrl(path, 60 * 60 * 24 * 7);
  }

  Future<void> markAsRead(String messageId) async {
    await _client.from('chat_messages').update({
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }

  /// Lista de conversas do usuário atual — última mensagem + não lidas.
  Future<List<ChatConversation>> getConversations() async {
    final userId = SupabaseConfig.auth.currentUser!.id;

    final rows = await _client
        .from('chat_messages')
        .select(
            '*, sender:sender_id(full_name, avatar_url), receiver:receiver_id(full_name, avatar_url)')
        .or('sender_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false)
        .limit(500);

    // Agrupar por peer
    final byPeer = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      final senderId = row['sender_id'] as String;
      final receiverId = row['receiver_id'] as String;
      final peerId = senderId == userId ? receiverId : senderId;
      (byPeer[peerId] ??= []).add(row);
    }

    return byPeer.entries.map((e) {
      final peerId = e.key;
      final messages = e.value;
      final last = messages.first;
      final profile = last['sender_id'] == userId
          ? last['receiver'] as Map<String, dynamic>?
          : last['sender'] as Map<String, dynamic>?;
      final unread = messages
          .where((m) =>
              m['receiver_id'] == userId &&
              m['read_at'] == null)
          .length;
      final preview = (last['image_url'] != null
          ? '📷 Foto'
          : (last['content'] as String? ?? ''));
      return ChatConversation(
        peerId: peerId,
        peerName: profile?['full_name'] as String? ?? 'Alguém',
        peerAvatar: profile?['avatar_url'] as String?,
        lastMessage: preview,
        lastAt: DateTime.parse(last['created_at'] as String),
        unreadCount: unread,
      );
    }).toList()
      ..sort((a, b) => b.lastAt.compareTo(a.lastAt));
  }

  static ModerationStatus _parseModeration(String? s) {
    return switch (s) {
      'approved' => ModerationStatus.approved,
      'pending' => ModerationStatus.pending,
      'rejected' => ModerationStatus.rejected,
      _ => ModerationStatus.approved,
    };
  }
}
