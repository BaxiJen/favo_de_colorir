import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/cobranca.dart';
import '../../services/billing_service.dart';

class AdminBillingScreen extends ConsumerStatefulWidget {
  const AdminBillingScreen({super.key});

  @override
  ConsumerState<AdminBillingScreen> createState() =>
      _AdminBillingScreenState();
}

class _AdminBillingScreenState extends ConsumerState<AdminBillingScreen> {
  late String _selectedMonth;
  bool _isTotalizing = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final billsAsync = ref.watch(monthBillsProvider(_selectedMonth));
    final summaryFuture = ref.watch(
      FutureProvider<Map<String, double>>((ref) {
        return ref.read(billingServiceProvider).getMonthSummary(_selectedMonth);
      }),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel Financeiro'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(
            icon: _isTotalizing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.calculate),
            onPressed: _isTotalizing ? null : _totalize,
            tooltip: 'Totalizar mês',
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary
          summaryFuture.when(
            loading: () => const LinearProgressIndicator(),
            error: (_, _) => const SizedBox.shrink(),
            data: (summary) => Container(
              padding: const EdgeInsets.all(16),
              color: FavoColors.honeyLight,
              child: Row(
                children: [
                  _SummaryChip('Total', summary['total'] ?? 0, FavoColors.honeyDark),
                  const SizedBox(width: 12),
                  _SummaryChip('Recebido', summary['paid'] ?? 0, FavoColors.success),
                  const SizedBox(width: 12),
                  _SummaryChip('Pendente', summary['pending'] ?? 0, FavoColors.error),
                ],
              ),
            ),
          ),

          // Bills list
          Expanded(
            child: billsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (bills) {
                if (bills.isEmpty) {
                  return const Center(
                    child: Text('Nenhuma cobrança neste mês'),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () =>
                      ref.refresh(monthBillsProvider(_selectedMonth).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: bills.length,
                    itemBuilder: (context, index) {
                      final item = bills[index];
                      return _AdminBillCard(item: item);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _totalize() async {
    setState(() => _isTotalizing = true);

    try {
      final result = await ref
          .read(billingServiceProvider)
          .totalizeBills(_selectedMonth);

      ref.invalidate(monthBillsProvider(_selectedMonth));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${result['created']} cobranças criadas'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isTotalizing = false);
    }
  }
}

class _AdminBillCard extends ConsumerWidget {
  final CobrancaWithStudent item;

  const _AdminBillCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = item.cobranca;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(item.studentName),
        subtitle: Text(
          'R\$ ${bill.totalAmount.toStringAsFixed(2)} · ${_statusLabel(bill.status)}',
        ),
        trailing: bill.status == CobrancaStatus.draft
            ? IconButton(
                icon: const Icon(Icons.check_circle_outline),
                color: FavoColors.success,
                onPressed: () async {
                  await ref
                      .read(billingServiceProvider)
                      .confirmBill(bill.id);
                  await ref
                      .read(billingServiceProvider)
                      .notifyBill(bill.id);
                  ref.invalidate(
                      monthBillsProvider(bill.monthYear));
                },
                tooltip: 'Confirmar e notificar',
              )
            : Icon(
                bill.isPaid ? Icons.check_circle : Icons.hourglass_empty,
                color: bill.isPaid ? FavoColors.success : FavoColors.honey,
              ),
      ),
    );
  }

  String _statusLabel(CobrancaStatus status) {
    return switch (status) {
      CobrancaStatus.draft => 'Rascunho',
      CobrancaStatus.pending => 'Pendente',
      CobrancaStatus.notified => 'Notificada',
      CobrancaStatus.paid => 'Pago',
      CobrancaStatus.overdue => 'Atrasado',
      CobrancaStatus.cancelled => 'Cancelado',
    };
  }
}

class _SummaryChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryChip(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color)),
          Text(
            'R\$ ${amount.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}
