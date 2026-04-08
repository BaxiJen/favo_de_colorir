import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/cobranca.dart';
import '../../services/billing_service.dart';

class MyPaymentsScreen extends ConsumerWidget {
  const MyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(myBillsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Pagamentos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: billsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (bills) {
          if (bills.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: FavoColors.warmGray),
                  SizedBox(height: 16),
                  Text('Nenhuma cobrança'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.refresh(myBillsProvider.future),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: bills.length,
              itemBuilder: (context, index) {
                return _BillCard(bill: bills[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _BillCard extends ConsumerWidget {
  final Cobranca bill;

  const _BillCard({required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  bill.monthYear,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Chip(
                  label: Text(
                    _statusLabel(bill.status),
                    style: TextStyle(
                      fontSize: 11,
                      color: _statusColor(bill.status),
                    ),
                  ),
                  backgroundColor: _statusColor(bill.status).withAlpha(25),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),

            _AmountRow('Mensalidade', bill.planAmount),
            _AmountRow('Argila', bill.clayAmount),
            _AmountRow('Queimas', bill.firingAmount),
            const Divider(height: 16),
            Row(
              children: [
                Text('Total',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(
                  'R\$ ${bill.totalAmount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: FavoColors.honeyDark,
                      ),
                ),
              ],
            ),

            if (bill.isPending) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showPaymentDialog(context, ref),
                  icon: const Icon(Icons.pix),
                  label: const Text('Pagar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentDialog(BuildContext context, WidgetRef ref) async {
    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Método de pagamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.pix),
              title: const Text('Pix'),
              subtitle: const Text('Sem taxas'),
              onTap: () => Navigator.pop(context, PaymentMethod.pix),
            ),
            ListTile(
              leading: const Icon(Icons.credit_card),
              title: const Text('Cartão'),
              subtitle: const Text('Via Nuvemshop'),
              onTap: () => Navigator.pop(context, PaymentMethod.card),
            ),
          ],
        ),
      ),
    );

    if (method == null) return;

    try {
      await ref
          .read(billingServiceProvider)
          .registerPayment(bill.id, method, null);
      ref.invalidate(myBillsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pagamento registrado!')),
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

  String _statusLabel(CobrancaStatus status) {
    return switch (status) {
      CobrancaStatus.draft => 'Rascunho',
      CobrancaStatus.pending => 'Pendente',
      CobrancaStatus.notified => 'Aguardando',
      CobrancaStatus.paid => 'Pago',
      CobrancaStatus.overdue => 'Atrasado',
      CobrancaStatus.cancelled => 'Cancelado',
    };
  }

  Color _statusColor(CobrancaStatus status) {
    return switch (status) {
      CobrancaStatus.paid => FavoColors.success,
      CobrancaStatus.overdue => FavoColors.error,
      CobrancaStatus.cancelled => FavoColors.warmGray,
      _ => FavoColors.honey,
    };
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final double amount;

  const _AmountRow(this.label, this.amount);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text('R\$ ${amount.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
