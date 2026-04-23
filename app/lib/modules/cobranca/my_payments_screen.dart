import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/error_handler.dart';
import '../../core/theme.dart';
import '../../models/cobranca.dart';
import '../../services/billing_service.dart';

class MyPaymentsScreen extends ConsumerWidget {
  const MyPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final billsAsync = ref.watch(myBillsProvider);

    return Scaffold(
      body: SafeArea(
        child: billsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erro: $e')),
          data: (bills) {
            final current = bills.isNotEmpty ? bills.first : null;
            final history = bills.length > 1 ? bills.sublist(1) : <Cobranca>[];

            return RefreshIndicator(
              onRefresh: () => ref.refresh(myBillsProvider.future),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Text('Meus Pagamentos',
                      style: Theme.of(context).textTheme.headlineLarge),
                  if (current != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Ciclo: ${current.monthYear}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: 24),

                  // Current bill hero
                  if (current != null) ...[
                    _CurrentBillCard(bill: current),
                    const SizedBox(height: 24),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: FavoColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long,
                              size: 48,
                              color: FavoColors.onSurfaceVariant
                                  .withAlpha(80)),
                          const SizedBox(height: 16),
                          Text('Nenhuma cobrança',
                              style:
                                  Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // History
                  if (history.isNotEmpty) ...[
                    Text('Histórico',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ...history.map((bill) => _HistoryRow(bill: bill)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CurrentBillCard extends ConsumerWidget {
  final Cobranca bill;

  const _CurrentBillCard({required this.bill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          // Status chip
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _statusColor(bill.status).withAlpha(20),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(bill.status).toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: _statusColor(bill.status),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
            ),
          ),
          const SizedBox(height: 16),

          // Total
          Text(
            'R\$',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: FavoColors.onSurfaceVariant,
                ),
          ),
          Text(
            bill.totalAmount.toStringAsFixed(2).replaceAll('.', ','),
            style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 20),

          // Breakdown — itens reais da cobrança
          _ItemsBreakdown(cobrancaId: bill.id, fallback: bill),
          const SizedBox(height: 20),

          if (bill.hasComprovante) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FavoColors.primaryContainer.withAlpha(40),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_outlined,
                      color: FavoColors.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bill.comprovanteUploadedAt == null
                          ? 'Comprovante enviado.'
                          : 'Comprovante enviado em ${DateFormat('dd/MM HH:mm').format(bill.comprovanteUploadedAt!)}. Aguardando confirmação.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Pay button
          if (bill.isPending) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _pay(context, ref),
                icon: const Icon(Icons.pix, size: 18),
                label: const Text('Pagar com Pix'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _uploadComprovante(context, ref),
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(bill.hasComprovante
                    ? 'Substituir comprovante'
                    : 'Enviar comprovante (paguei por fora)'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _uploadComprovante(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (img == null || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(
      duration: Duration(seconds: 20),
      content: Text('Enviando comprovante...'),
    ));
    try {
      final bytes = kIsWeb ? await img.readAsBytes() : null;
      await ref.read(billingServiceProvider).uploadComprovante(
            cobrancaId: bill.id,
            filename: img.name,
            bytes: bytes,
            file: kIsWeb ? null : File(img.path),
          );
      ref.invalidate(myBillsProvider);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(const SnackBar(
        content: Text('Comprovante enviado. Admin vai confirmar.'),
      ));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
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
          const SnackBar(
              content:
                  Text('Pagamento registrado — aguarde confirmação do admin.')),
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
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
      _ => FavoColors.primary,
    };
  }
}

/// Breakdown lido de cobranca_itens (substitui os hardcoded "3 kg / 2 peças").
class _ItemsBreakdown extends ConsumerWidget {
  final String cobrancaId;
  final Cobranca fallback;
  const _ItemsBreakdown({required this.cobrancaId, required this.fallback});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<List<CobrancaItem>>(
      future: ref.read(billingServiceProvider).getBillItems(cobrancaId),
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        final items = snap.data ?? const <CobrancaItem>[];
        if (items.isEmpty) {
          // Fallback: mostra apenas valores agregados se a cobrança não tem itens ainda
          return Column(
            children: [
              if (fallback.planAmount > 0)
                _BreakdownRow(label: 'Plano', value: fallback.planAmount),
              if (fallback.clayAmount > 0)
                _BreakdownRow(label: 'Argila', value: fallback.clayAmount),
              if (fallback.firingAmount > 0)
                _BreakdownRow(label: 'Queimas', value: fallback.firingAmount),
            ],
          );
        }
        return Column(
          children: items
              .map((it) =>
                  _BreakdownRow(label: it.description, value: it.total))
              .toList(),
        );
      },
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final double value;

  const _BreakdownRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child:
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            'R\$ ${value.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Cobranca bill;

  const _HistoryRow({required this.bill});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            bill.isPaid ? Icons.check_circle : Icons.hourglass_empty,
            size: 20,
            color: bill.isPaid ? FavoColors.success : FavoColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(bill.monthYear,
                style: Theme.of(context).textTheme.titleSmall),
          ),
          Text(
            'R\$ ${bill.totalAmount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
