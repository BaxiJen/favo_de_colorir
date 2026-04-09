import 'package:flutter_test/flutter_test.dart';

import 'package:favo/services/community_service.dart';

void main() {
  group('ChatMessage', () {
    test('fromJson parses all fields', () {
      final msg = ChatMessage.fromJson({
        'id': 'msg-1',
        'sender_id': 'user-1',
        'receiver_id': 'user-2',
        'content': 'Olá professora!',
        'read_at': '2026-04-09T10:00:00Z',
        'created_at': '2026-04-09T09:00:00Z',
      });

      expect(msg.id, 'msg-1');
      expect(msg.senderId, 'user-1');
      expect(msg.receiverId, 'user-2');
      expect(msg.content, 'Olá professora!');
      expect(msg.readAt, isNotNull);
      expect(msg.createdAt, DateTime.utc(2026, 4, 9, 9, 0));
    });

    test('fromJson handles null read_at', () {
      final msg = ChatMessage.fromJson({
        'id': 'msg-2',
        'sender_id': 'user-1',
        'receiver_id': 'user-2',
        'content': 'Oi!',
        'read_at': null,
        'created_at': '2026-04-09T09:00:00Z',
      });

      expect(msg.readAt, isNull);
    });
  });

  group('CommunityPost', () {
    test('constructor creates post with correct fields', () {
      final post = CommunityPost(
        id: 'post-1',
        authorId: 'user-1',
        content: 'Minha nova caneca!',
        imageUrls: ['https://example.com/img.jpg'],
        isFlagged: false,
        createdAt: DateTime(2026, 4, 9),
        authorName: 'Ana Silva',
        authorAvatar: null,
        likeCount: 5,
        commentCount: 2,
        likedByMe: true,
      );

      expect(post.content, 'Minha nova caneca!');
      expect(post.imageUrls.length, 1);
      expect(post.likeCount, 5);
      expect(post.commentCount, 2);
      expect(post.likedByMe, true);
      expect(post.isFlagged, false);
    });

    test('post with empty images', () {
      final post = CommunityPost(
        id: 'post-2',
        authorId: 'user-1',
        content: 'Texto simples',
        imageUrls: [],
        isFlagged: false,
        createdAt: DateTime(2026, 4, 9),
        authorName: 'Maria',
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
      );

      expect(post.imageUrls, isEmpty);
      expect(post.likedByMe, false);
    });

    test('flagged post', () {
      final post = CommunityPost(
        id: 'post-3',
        authorId: 'user-1',
        content: 'Conteúdo inadequado',
        imageUrls: [],
        isFlagged: true,
        createdAt: DateTime(2026, 4, 9),
        authorName: 'User',
        likeCount: 0,
        commentCount: 0,
        likedByMe: false,
      );

      expect(post.isFlagged, true);
    });
  });

  group('CommunityComment', () {
    test('constructor creates comment correctly', () {
      final comment = CommunityComment(
        id: 'c-1',
        postId: 'post-1',
        authorId: 'user-2',
        content: 'Que linda!',
        createdAt: DateTime(2026, 4, 9, 14, 30),
        authorName: 'Julia Oliveira',
      );

      expect(comment.content, 'Que linda!');
      expect(comment.authorName, 'Julia Oliveira');
      expect(comment.postId, 'post-1');
    });
  });

  group('ChatConversation', () {
    test('constructor creates conversation correctly', () {
      final conv = ChatConversation(
        peerId: 'user-2',
        peerName: 'Professora Débora',
        peerAvatar: null,
        lastMessage: 'Sua peça ficou ótima!',
        lastAt: DateTime(2026, 4, 9, 15, 0),
        unreadCount: 3,
      );

      expect(conv.peerName, 'Professora Débora');
      expect(conv.unreadCount, 3);
      expect(conv.peerAvatar, isNull);
    });
  });
}
