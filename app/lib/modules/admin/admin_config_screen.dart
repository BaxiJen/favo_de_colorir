import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../services/material_service.dart';

class AdminConfigScreen extends ConsumerWidget {
  const AdminConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tiposArgila = ref.watch(tiposArgilaProvider);
    final tiposPeca = ref.watch(tiposPecaProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Preços de Argila',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          tiposArgila.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Erro: $e'),
            data: (tipos) => Column(
              children: tipos
                  .map((t) => _PriceRow(
                        label: t.name,
                        price: t.pricePerKg,
                        suffix: '/kg',
                        onSave: (newPrice) async {
                          await ref
                              .read(materialServiceProvider)
                              .updateClayPrice(t.id, newPrice);
                          ref.invalidate(tiposArgilaProvider);
                        },
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 28),

          Text('Preços de Queima (Esmalte)',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          tiposPeca.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Erro: $e'),
            data: (tipos) => Column(
              children: tipos
                  .map((t) => _PriceRow(
                        label: t.name,
                        price: t.glazeFiringPrice,
                        suffix: '/peça',
                        onSave: (newPrice) async {
                          await ref
                              .read(materialServiceProvider)
                              .updateFiringPrice(t.id, newPrice);
                          ref.invalidate(tiposPecaProvider);
                        },
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final double price;
  final String suffix;
  final Future<void> Function(double) onSave;

  const _PriceRow({
    required this.label,
    required this.price,
    required this.suffix,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text('R\$ ${price.toStringAsFixed(2)}$suffix',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            color: FavoColors.primary,
            onPressed: () async {
              final ctrl =
                  TextEditingController(text: price.toStringAsFixed(2));
              final result = await showDialog<double>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('Editar preço: $label'),
                  content: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(prefixText: 'R\$ '),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final v = double.tryParse(ctrl.text);
                        if (v != null) Navigator.pop(ctx, v);
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              );
              if (result == null) return;
              // Confirm dialog pra evitar typo (ex: 8.50 → 85.00)
              final diff = ((result - price) / price * 100).abs();
              if (diff > 30 && context.mounted) {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Mudança grande de preço'),
                    content: Text(
                        '$label vai de R\$ ${price.toStringAsFixed(2)} para R\$ ${result.toStringAsFixed(2)} (${diff.toStringAsFixed(0)}% de diferença). Confirmar?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancelar')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Confirmar')),
                    ],
                  ),
                );
                if (ok != true) return;
              }
              await onSave(result);
            },
          ),
        ],
      ),
    );
  }
}
