import 'package:flutter_test/flutter_test.dart';

import 'package:favo/models/profile.dart';

void main() {
  group('Profile onboarding flag', () {
    test('hasOnboarded false quando onboarded_at é null', () {
      final p = _build(onboardedAt: null);
      expect(p.hasOnboarded, false);
    });

    test('hasOnboarded true quando onboarded_at tem timestamp', () {
      final p = _build(onboardedAt: DateTime.parse('2026-04-23T10:00:00Z'));
      expect(p.hasOnboarded, true);
    });

    test('fromJson parseia onboarded_at', () {
      final json = _baseJson();
      json['onboarded_at'] = '2026-04-23T10:00:00Z';
      final p = Profile.fromJson(json);
      expect(p.onboardedAt, DateTime.parse('2026-04-23T10:00:00Z'));
      expect(p.hasOnboarded, true);
    });

    test('fromJson aceita onboarded_at ausente', () {
      final json = _baseJson();
      final p = Profile.fromJson(json);
      expect(p.onboardedAt, isNull);
      expect(p.hasOnboarded, false);
    });

    test('toJson serializa onboarded_at', () {
      final p = _build(onboardedAt: DateTime.parse('2026-04-23T10:00:00Z'));
      expect(p.toJson()['onboarded_at'], isNotNull);
    });

    test('toJson com null escreve null', () {
      final p = _build(onboardedAt: null);
      expect(p.toJson()['onboarded_at'], isNull);
    });
  });
}

Map<String, dynamic> _baseJson() => {
      'id': 'u-1',
      'full_name': 'Ana Silva',
      'email': 'ana@example.com',
      'role': 'student',
      'status': 'active',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    };

Profile _build({DateTime? onboardedAt}) => Profile(
      id: 'u-1',
      fullName: 'Ana Silva',
      email: 'ana@example.com',
      role: UserRole.student,
      status: UserStatus.active,
      onboardedAt: onboardedAt,
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      updatedAt: DateTime.parse('2026-01-01T00:00:00Z'),
    );
