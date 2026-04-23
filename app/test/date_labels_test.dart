import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:favo/core/date_labels.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('whenLabel', () {
    final ref = DateTime(2026, 4, 22, 14, 0); // quarta 14:00

    test('mesmo dia → Hoje', () {
      expect(whenLabel(DateTime(2026, 4, 22, 19, 0), ref: ref), 'Hoje');
      // Hora do dia não afeta
      expect(whenLabel(DateTime(2026, 4, 22, 0, 1), ref: ref), 'Hoje');
      expect(whenLabel(DateTime(2026, 4, 22, 23, 59), ref: ref), 'Hoje');
    });

    test('dia seguinte → Amanhã', () {
      expect(whenLabel(DateTime(2026, 4, 23), ref: ref), 'Amanhã');
    });

    test('2 a 6 dias à frente → dia da semana em PT-BR maiúsculo', () {
      expect(whenLabel(DateTime(2026, 4, 24), ref: ref),
          'SEXTA-FEIRA'); // +2 dias
      expect(whenLabel(DateTime(2026, 4, 25), ref: ref),
          'SÁBADO'); // +3 dias
      expect(whenLabel(DateTime(2026, 4, 27), ref: ref),
          'SEGUNDA-FEIRA'); // +5 dias
      expect(whenLabel(DateTime(2026, 4, 28), ref: ref),
          'TERÇA-FEIRA'); // +6 dias
    });

    test('7+ dias → dd/MM', () {
      expect(whenLabel(DateTime(2026, 4, 29), ref: ref), '29/04');
      expect(whenLabel(DateTime(2026, 5, 15), ref: ref), '15/05');
    });

    test('data passada (negativo) → dd/MM', () {
      expect(whenLabel(DateTime(2026, 4, 21), ref: ref), '21/04');
      expect(whenLabel(DateTime(2026, 1, 1), ref: ref), '01/01');
    });

    test('sem `ref` usa now — smoke test', () {
      // não quebrar com null ref
      final r = whenLabel(DateTime.now());
      expect(r.isNotEmpty, true);
    });
  });
}
