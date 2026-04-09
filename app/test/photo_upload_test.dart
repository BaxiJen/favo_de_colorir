import 'package:flutter_test/flutter_test.dart';

import 'package:favo/models/feed_entry.dart';

void main() {
  group('FeedPhoto model', () {
    test('fromJson parses all fields', () {
      final photo = FeedPhoto.fromJson({
        'id': 'fp-1',
        'feed_entry_id': 'fe-1',
        'storage_path': 'user1/fe-1/0_123456.jpg',
        'thumbnail_path': null,
        'caption': 'Minha caneca favorita',
        'sort_order': 0,
        'created_at': '2026-04-09T10:00:00Z',
      });

      expect(photo.id, 'fp-1');
      expect(photo.storagePath, 'user1/fe-1/0_123456.jpg');
      expect(photo.caption, 'Minha caneca favorita');
      expect(photo.sortOrder, 0);
      expect(photo.thumbnailPath, isNull);
    });

    test('fromJson with thumbnail', () {
      final photo = FeedPhoto.fromJson({
        'id': 'fp-2',
        'feed_entry_id': 'fe-1',
        'storage_path': 'user1/fe-1/1_789.jpg',
        'thumbnail_path': 'user1/fe-1/1_789_thumb.jpg',
        'caption': null,
        'sort_order': 1,
        'created_at': '2026-04-09T10:00:00Z',
      });

      expect(photo.thumbnailPath, 'user1/fe-1/1_789_thumb.jpg');
      expect(photo.caption, isNull);
      expect(photo.sortOrder, 1);
    });
  });

  group('FeedEntry with photos', () {
    test('entry with multiple photos', () {
      final entry = FeedEntry.fromJson({
        'id': 'fe-1',
        'student_id': 's-1',
        'aula_id': null,
        'peca_id': null,
        'entry_type': 'photo',
        'content': 'Minhas peças da semana',
        'note_color': null,
        'is_public': true,
        'created_at': '2026-04-09T00:00:00Z',
        'updated_at': '2026-04-09T00:00:00Z',
        'feed_photos': [
          {
            'id': 'fp-1',
            'feed_entry_id': 'fe-1',
            'storage_path': 'path/photo1.jpg',
            'thumbnail_path': null,
            'caption': 'Caneca',
            'sort_order': 0,
            'created_at': '2026-04-09T00:00:00Z',
          },
          {
            'id': 'fp-2',
            'feed_entry_id': 'fe-1',
            'storage_path': 'path/photo2.jpg',
            'thumbnail_path': null,
            'caption': 'Prato',
            'sort_order': 1,
            'created_at': '2026-04-09T00:00:00Z',
          },
        ],
      });

      expect(entry.entryType, FeedEntryType.photo);
      expect(entry.photos, isNotNull);
      expect(entry.photos!.length, 2);
      expect(entry.photos!.first.caption, 'Caneca');
      expect(entry.photos!.last.sortOrder, 1);
      expect(entry.isPublic, true);
    });
  });

  group('Storage path construction', () {
    test('avatar path format', () {
      const userId = 'abc-123';
      const ext = 'jpg';
      final path = '$userId/avatar.$ext';
      expect(path, 'abc-123/avatar.jpg');
    });

    test('feed photo path format', () {
      const userId = 'abc-123';
      const entryId = 'fe-456';
      const sortOrder = 0;
      final ts = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/$entryId/${sortOrder}_$ts.jpg';
      expect(path.startsWith('abc-123/fe-456/0_'), true);
      expect(path.endsWith('.jpg'), true);
    });
  });
}
