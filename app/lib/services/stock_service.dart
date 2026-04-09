import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';

final stockServiceProvider = Provider<StockService>((ref) {
  return StockService();
});

final stockLevelsProvider = FutureProvider<List<StockLevel>>((ref) {
  return ref.read(stockServiceProvider).getStockLevels();
});

class StockLevel {
  final String id;
  final String tipoArgilaId;
  final String tipoArgilaName;
  final double quantidadeKg;
  final double nivelMinimoKg;
  final bool isLow;

  const StockLevel({
    required this.id,
    required this.tipoArgilaId,
    required this.tipoArgilaName,
    required this.quantidadeKg,
    required this.nivelMinimoKg,
    required this.isLow,
  });
}

class StockService {
  final _client = SupabaseConfig.client;

  Future<List<StockLevel>> getStockLevels() async {
    final data = await _client
        .from('estoque_argila')
        .select('*, tipos_argila(name)')
        .order('tipo_argila_id');

    return data.map((row) {
      final qty = (row['quantidade_kg'] as num).toDouble();
      final min = (row['nivel_minimo_kg'] as num).toDouble();
      final tipoData = row['tipos_argila'] as Map<String, dynamic>?;

      return StockLevel(
        id: row['id'] as String,
        tipoArgilaId: row['tipo_argila_id'] as String,
        tipoArgilaName: tipoData?['name'] as String? ?? '',
        quantidadeKg: qty,
        nivelMinimoKg: min,
        isLow: qty <= min,
      );
    }).toList();
  }

  Future<void> registerPurchase({
    required String tipoArgilaId,
    required double quantidadeKg,
    double? precoTotal,
    String? fornecedor,
  }) async {
    await _client.from('estoque_compras').insert({
      'tipo_argila_id': tipoArgilaId,
      'quantidade_kg': quantidadeKg,
      'preco_total': precoTotal,
      'fornecedor': fornecedor,
      'registrado_por': SupabaseConfig.auth.currentUser!.id,
    });
  }

  Future<void> updateMinLevel(String estoqueId, double newMin) async {
    await _client
        .from('estoque_argila')
        .update({'nivel_minimo_kg': newMin})
        .eq('id', estoqueId);
  }

  Future<void> initializeStock(String tipoArgilaId, double qty) async {
    await _client.from('estoque_argila').upsert({
      'tipo_argila_id': tipoArgilaId,
      'quantidade_kg': qty,
    });
  }
}
