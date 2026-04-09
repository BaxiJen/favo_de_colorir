import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/material_service.dart';
import '../../services/stock_service.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stockAsync = ref.watch(stockLevelsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Estoque de Argilas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addPurchase(context, ref),
        child: const Icon(Icons.add_shopping_cart),
      ),
      body: stockAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (levels) {
          if (levels.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 48,
                      color: FavoColors.onSurfaceVariant.withAlpha(80)),
                  const SizedBox(height: 16),
                  Text('Nenhum estoque cadastrado',
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => _initStock(context, ref),
                    child: const Text('Inicializar Estoque'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(stockLevelsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: levels.length,
              itemBuilder: (context, index) =>
                  _StockCard(level: levels[index]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _initStock(BuildContext context, WidgetRef ref) async {
    try {
      final tipos = await ref.read(tiposArgilaProvider.future);
      for (final tipo in tipos) {
        await ref.read(stockServiceProvider).initializeStock(tipo.id, 20);
      }
      ref.invalidate(stockLevelsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Estoque inicializado!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }

  Future<void> _addPurchase(BuildContext context, WidgetRef ref) async {
    final tipos = await ref.read(tiposArgilaProvider.future);
    String? selectedTipo;
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Registrar Compra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Tipo de argila'),
                items: tipos
                    .map((t) => DropdownMenuItem(
                        value: t.id, child: Text(t.name)))
                    .toList(),
                onChanged: (v) => setState(() => selectedTipo = v),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Quantidade (kg)', suffixText: 'kg'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: priceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'Preço total (opcional)', prefixText: 'R\$ '),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Registrar')),
          ],
        ),
      ),
    );

    if (result != true || selectedTipo == null || qtyCtrl.text.isEmpty) return;

    try {
      await ref.read(stockServiceProvider).registerPurchase(
            tipoArgilaId: selectedTipo!,
            quantidadeKg: double.parse(qtyCtrl.text),
            precoTotal: double.tryParse(priceCtrl.text),
          );
      ref.invalidate(stockLevelsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compra registrada!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    }
  }
}

class _StockCard extends StatelessWidget {
  final StockLevel level;

  const _StockCard({required this.level});

  @override
  Widget build(BuildContext context) {
    final pct = level.nivelMinimoKg > 0
        ? (level.quantidadeKg / (level.nivelMinimoKg * 3)).clamp(0.0, 1.0)
        : 1.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(level.tipoArgilaName,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              if (level.isLow)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FavoColors.error.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning, size: 14, color: FavoColors.error),
                      const SizedBox(width: 4),
                      Text('BAIXO',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                  color: FavoColors.error,
                                  fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: FavoColors.surfaceContainerHigh,
              color: level.isLow ? FavoColors.error : FavoColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${level.quantidadeKg.toStringAsFixed(1)} kg',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: level.isLow ? FavoColors.error : FavoColors.onSurface,
                    ),
              ),
              const Spacer(),
              Text(
                'Mín: ${level.nivelMinimoKg.toStringAsFixed(0)} kg',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
