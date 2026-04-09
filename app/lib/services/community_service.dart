import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';

final communityServiceProvider = Provider<CommunityService>((ref) {
  return CommunityService();
});

final communityFeedProvider = FutureProvider<List<CommunityPost>>((ref) {
  return ref.read(communityServiceProvider).getFeed();
});

class CommunityPost {
  final String id;
  final String authorId;
  final String? content;
  final List<String> imageUrls;
  final bool isFlagged;
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
  final DateTime createdAt;
  final String authorName;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    required this.authorName,
  });
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
  final DateTime? readAt;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.readAt,
    required this.createdAt,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      content: json['content'] as String,
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
        createdAt: DateTime.parse(row['created_at'] as String),
        authorName: profile?['full_name'] as String? ?? '',
        authorAvatar: profile?['avatar_url'] as String?,
        likeCount: postLikes.length,
        commentCount: commentCountByPost[postId] ?? 0,
        likedByMe: postLikes.any((l) => l['user_id'] == userId),
      );
    }).toList();
  }

  Future<void> createPost(String content, {List<String>? imageUrls}) async {
    await _client.from('community_posts').insert({
      'author_id': SupabaseConfig.auth.currentUser!.id,
      'content': content,
      'image_urls': imageUrls ?? [],
    });
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
        .select('*, profiles:author_id(full_name)')
        .eq('post_id', postId)
        .order('created_at');

    return data.map((row) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      return CommunityComment(
        id: row['id'] as String,
        postId: row['post_id'] as String,
        authorId: row['author_id'] as String,
        content: row['content'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        authorName: profile?['full_name'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> addComment(String postId, String content) async {
    await _client.from('community_comments').insert({
      'post_id': postId,
      'author_id': SupabaseConfig.auth.currentUser!.id,
      'content': content,
    });
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

  Future<void> sendMessage(String receiverId, String content) async {
    await _client.from('chat_messages').insert({
      'sender_id': SupabaseConfig.auth.currentUser!.id,
      'receiver_id': receiverId,
      'content': content,
    });
  }

  Future<void> markAsRead(String messageId) async {
    await _client.from('chat_messages').update({
      'read_at': DateTime.now().toIso8601String(),
    }).eq('id', messageId);
  }
}
