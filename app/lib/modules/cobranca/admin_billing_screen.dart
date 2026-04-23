import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error_handler.dart';
import '../../core/supabase_client.dart';
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
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Text(_selectedMonth,
              style: Theme.of(context).textTheme.labelLarge),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
          IconButton(
            icon: _isTotalizing
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.calculate),
            onPressed: _isTotalizing ? null : _totalize,
            tooltip: 'Totalizar mês',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportCSV,
            tooltip: 'Exportar CSV',
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
              padding: const EdgeInsets.all(20),
              color: FavoColors.surfaceContainerLow,
              child: Row(
                children: [
                  _SummaryItem('Total', summary['total'] ?? 0, FavoColors.onSurface),
                  _SummaryItem('Recebido', summary['paid'] ?? 0, FavoColors.success),
                  _SummaryItem('Pendente', summary['pending'] ?? 0, FavoColors.error),
                ],
              ),
            ),
          ),

          // Filters
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              children: [
                _buildChip('Todos', 'all'),
                _buildChip('Rascunho', 'draft'),
                _buildChip('Pendente', 'pending'),
                _buildChip('Pago', 'paid'),
                _buildChip('Atrasado', 'overdue'),
              ],
            ),
          ),

          // Bills
          Expanded(
            child: billsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erro: $e')),
              data: (bills) {
                final filtered = _statusFilter == 'all'
                    ? bills
                    : bills.where((b) => b.cobranca.status.name == _statusFilter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 48,
                            color: FavoColors.onSurfaceVariant.withAlpha(80)),
                        const SizedBox(height: 16),
                        Text('Nenhuma cobrança',
                            style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(monthBillsProvider(_selectedMonth).future),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _BillCard(item: filtered[index], monthYear: _selectedMonth),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: _statusFilter == value,
        onSelected: (_) => setState(() => _statusFilter = value),
      ),
    );
  }

  void _changeMonth(int delta) {
    final parts = _selectedMonth.split('-');
    var year = int.parse(parts[0]);
    var month = int.parse(parts[1]) + delta;
    if (month > 12) { month = 1; year++; }
    else if (month < 1) { month = 12; year--; }
    setState(() => _selectedMonth = '$year-${month.toString().padLeft(2, '0')}');
  }

  Future<void> _totalize() async {
    setState(() => _isTotalizing = true);
    try {
      final result = await ref.read(billingServiceProvider).totalizeBills(_selectedMonth);
      ref.invalidate(monthBillsProvider(_selectedMonth));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${result['created']} cobranças criadas')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    } finally {
      if (mounted) setState(() => _isTotalizing = false);
    }
  }

  Future<void> _exportCSV() async {
    try {
      final response = await SupabaseConfig.client.functions.invoke(
        'exportar-cobranca',
        body: {'month_year': _selectedMonth, 'format': 'csv'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV gerado (${(response.data as String).split('\n').length - 1} linhas)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
      }
    }
  }
}

class _BillCard extends ConsumerWidget {
  final CobrancaWithStudent item;
  final String monthYear;

  const _BillCard({required this.item, required this.monthYear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bill = item.cobranca;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: FavoColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: ExpansionTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: _statusColor(bill.status).withAlpha(25),
          child: Icon(_statusIcon(bill.status), color: _statusColor(bill.status), size: 18),
        ),
        title: Text(item.studentName, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          'R\$ ${bill.totalAmount.toStringAsFixed(2)} · ${_statusLabel(bill.status)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                _Row('Mensalidade', bill.planAmount),
                _Row('Argila', bill.clayAmount),
                _Row('Queimas', bill.firingAmount),
                Divider(color: FavoColors.outlineVariant.withAlpha(40)),
                _Row('Total', bill.totalAmount, bold: true),
                if (bill.hasComprovante) ...[
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () =>
                        _openComprovante(context, bill.comprovanteUrl!),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FavoColors.primaryContainer.withAlpha(40),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_outlined,
                              size: 16, color: FavoColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Comprovante enviado — toque pra ver',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          const Icon(Icons.open_in_new, size: 14),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Actions
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (bill.status == CobrancaStatus.draft)
                      OutlinedButton(
                        onPressed: () =>
                            _confirmAction(context, ref, bill.id),
                        child: const Text('Confirmar'),
                      ),
                    if (bill.status == CobrancaStatus.pending)
                      ElevatedButton.icon(
                        onPressed: () => _notifyAction(context, ref, bill.id),
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Notificar'),
                      ),
                    if (bill.hasComprovante && !bill.isPaid)
                      ElevatedButton.icon(
                        onPressed: () =>
                            _confirmComprovante(context, ref, bill.id),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Confirmar recebimento'),
                      ),
                    if ((bill.status == CobrancaStatus.notified ||
                            bill.status == CobrancaStatus.overdue ||
                            bill.status == CobrancaStatus.pending) &&
                        !bill.hasComprovante)
                      OutlinedButton(
                        onPressed: () =>
                            _manualPaymentDialog(context, ref, bill.id),
                        child: const Text('Pgto Manual'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAction(
      BuildContext context, WidgetRef ref, String billId) async {
    try {
      await ref.read(billingServiceProvider).confirmBill(billId);
      ref.invalidate(monthBillsProvider(monthYear));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _notifyAction(
      BuildContext context, WidgetRef ref, String billId) async {
    try {
      await ref.read(billingServiceProvider).notifyBill(billId);
      ref.invalidate(monthBillsProvider(monthYear));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aluna/aluno notificado.')),
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _confirmComprovante(
      BuildContext context, WidgetRef ref, String billId) async {
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar recebimento?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Marque como paga e registre observação opcional.'),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                  hintText: 'Ex: Recebido em dinheiro no dia 22.'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(billingServiceProvider).confirmComprovante(
            billId,
            paymentNotes: notesCtrl.text.trim().isEmpty
                ? null
                : notesCtrl.text.trim(),
          );
      ref.invalidate(monthBillsProvider(monthYear));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _manualPaymentDialog(
      BuildContext context, WidgetRef ref, String billId) async {
    PaymentMethod method = PaymentMethod.external;
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Pagamento manual'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Como a pessoa pagou?'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Dinheiro'),
                    selected: method == PaymentMethod.external,
                    onSelected: (_) =>
                        setState(() => method = PaymentMethod.external),
                  ),
                  ChoiceChip(
                    label: const Text('Pix (fora do app)'),
                    selected: method == PaymentMethod.pix,
                    onSelected: (_) =>
                        setState(() => method = PaymentMethod.pix),
                  ),
                  ChoiceChip(
                    label: const Text('Cartão'),
                    selected: method == PaymentMethod.card,
                    onSelected: (_) =>
                        setState(() => method = PaymentMethod.card),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration:
                    const InputDecoration(hintText: 'Observações (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(billingServiceProvider).registerPayment(
            billId,
            method,
            'manual',
            adminConfirmed: true,
            paymentNotes:
                notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
          );
      ref.invalidate(monthBillsProvider(monthYear));
    } catch (e) {
      if (context.mounted) showErrorSnackBar(context, e);
    }
  }

  Future<void> _openComprovante(BuildContext context, String url) async {
    await showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: InteractiveViewer(
          child: Image.network(
            url,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                  'Não foi possível carregar. Peça pra aluna/aluno reenviar.'),
            ),
          ),
        ),
      ),
    );
  }

  IconData _statusIcon(CobrancaStatus s) => switch (s) {
    CobrancaStatus.draft => Icons.edit_note,
    CobrancaStatus.pending => Icons.hourglass_empty,
    CobrancaStatus.notified => Icons.mark_email_read,
    CobrancaStatus.paid => Icons.check_circle,
    CobrancaStatus.overdue => Icons.warning,
    CobrancaStatus.cancelled => Icons.cancel,
  };

  Color _statusColor(CobrancaStatus s) => switch (s) {
    CobrancaStatus.paid => FavoColors.success,
    CobrancaStatus.overdue => FavoColors.error,
    CobrancaStatus.cancelled => FavoColors.outline,
    _ => FavoColors.primary,
  };

  String _statusLabel(CobrancaStatus s) => switch (s) {
    CobrancaStatus.draft => 'Rascunho',
    CobrancaStatus.pending => 'Pendente',
    CobrancaStatus.notified => 'Notificada',
    CobrancaStatus.paid => 'Pago',
    CobrancaStatus.overdue => 'Atrasado',
    CobrancaStatus.cancelled => 'Cancelado',
  };
}

class _Row extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;

  const _Row(this.label, this.amount, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text('R\$ ${amount.toStringAsFixed(2)}', style: style),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;

  const _SummaryItem(this.label, this.amount, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
          Text('R\$ ${amount.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}
