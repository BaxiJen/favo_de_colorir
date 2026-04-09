import 'package:flutter_test/flutter_test.dart';

import 'package:favo/services/stock_service.dart';

void main() {
  group('StockLevel', () {
    test('isLow when quantity at minimum', () {
      final level = StockLevel(
        id: 'e-1',
        tipoArgilaId: 'ta-1',
        tipoArgilaName: 'Branca',
        quantidadeKg: 10.0,
        nivelMinimoKg: 10.0,
        isLow: true,
      );

      expect(level.isLow, true);
      expect(level.tipoArgilaName, 'Branca');
    });

    test('isLow when quantity below minimum', () {
      final level = StockLevel(
        id: 'e-2',
        tipoArgilaId: 'ta-2',
        tipoArgilaName: 'Vermelha',
        quantidadeKg: 5.0,
        nivelMinimoKg: 10.0,
        isLow: true,
      );

      expect(level.isLow, true);
    });

    test('not low when quantity above minimum', () {
      final level = StockLevel(
        id: 'e-3',
        tipoArgilaId: 'ta-3',
        tipoArgilaName: 'Grês',
        quantidadeKg: 25.0,
        nivelMinimoKg: 10.0,
        isLow: false,
      );

      expect(level.isLow, false);
      expect(level.quantidadeKg, 25.0);
    });

    test('zero stock', () {
      final level = StockLevel(
        id: 'e-4',
        tipoArgilaId: 'ta-4',
        tipoArgilaName: 'Porcelana',
        quantidadeKg: 0.0,
        nivelMinimoKg: 10.0,
        isLow: true,
      );

      expect(level.quantidadeKg, 0.0);
      expect(level.isLow, true);
    });
  });
}
