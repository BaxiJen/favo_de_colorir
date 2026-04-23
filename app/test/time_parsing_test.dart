import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:favo/core/time_parsing.dart';

void main() {
  group('parseTimeOfDay', () {
    test('HH:MM:SS do Postgres', () {
      expect(parseTimeOfDay('09:00:00'), const TimeOfDay(hour: 9, minute: 0));
      expect(parseTimeOfDay('14:30:00'),
          const TimeOfDay(hour: 14, minute: 30));
      expect(parseTimeOfDay('23:59:00'),
          const TimeOfDay(hour: 23, minute: 59));
    });

    test('HH:MM também aceita', () {
      expect(parseTimeOfDay('09:30'), const TimeOfDay(hour: 9, minute: 30));
    });

    test('string vazia → 00:00', () {
      expect(parseTimeOfDay(''), const TimeOfDay(hour: 0, minute: 0));
    });

    test('hora 00:00 válida', () {
      expect(parseTimeOfDay('00:00:00'), const TimeOfDay(hour: 0, minute: 0));
    });

    test('hora inválida (>23) é clampada', () {
      expect(parseTimeOfDay('99:00:00'),
          const TimeOfDay(hour: 23, minute: 0));
    });

    test('minuto inválido (>59) é clampado', () {
      expect(parseTimeOfDay('10:75:00'),
          const TimeOfDay(hour: 10, minute: 59));
    });

    test('parte sem número → 0', () {
      expect(parseTimeOfDay('abc:xyz'),
          const TimeOfDay(hour: 0, minute: 0));
    });
  });

  group('timeOfDayToString', () {
    test('volta pra HH:MM:SS padded', () {
      expect(timeOfDayToString(const TimeOfDay(hour: 9, minute: 5)),
          '09:05:00');
      expect(timeOfDayToString(const TimeOfDay(hour: 14, minute: 30)),
          '14:30:00');
      expect(timeOfDayToString(const TimeOfDay(hour: 0, minute: 0)),
          '00:00:00');
    });

    test('round-trip preserva', () {
      const cases = ['09:00:00', '14:30:00', '23:59:00', '00:00:00'];
      for (final c in cases) {
        expect(timeOfDayToString(parseTimeOfDay(c)), c);
      }
    });
  });
}
