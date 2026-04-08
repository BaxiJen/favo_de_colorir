import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/supabase_client.dart';
import '../models/cobranca.dart';

final billingServiceProvider = Provider<BillingService>((ref) {
  return BillingService();
});

/// Cobranças do aluno logado
final myBillsProvider = FutureProvider<List<Cobranca>>((ref) async {
  final userId = SupabaseConfig.auth.currentUser?.id;
  if (userId == null) return [];
  return ref.read(billingServiceProvider).getStudentBills(userId);
});

/// Todas as cobranças de um mês (admin)
final monthBillsProvider =
    FutureProvider.family<List<CobrancaWithStudent>, String>((ref, monthYear) {
  return ref.read(billingServiceProvider).getMonthBills(monthYear);
});

class CobrancaWithStudent {
  final Cobranca cobranca;
  final String studentName;

  const CobrancaWithStudent({
    required this.cobranca,
    required this.studentName,
  });
}

class BillingService {
  final _client = SupabaseConfig.client;

  Future<List<Cobranca>> getStudentBills(String studentId) async {
    final data = await _client
        .from('cobrancas')
        .select()
        .eq('student_id', studentId)
        .order('month_year', ascending: false);
    return data.map((json) => Cobranca.fromJson(json)).toList();
  }

  Future<List<CobrancaItem>> getBillItems(String cobrancaId) async {
    final data = await _client
        .from('cobranca_itens')
        .select()
        .eq('cobranca_id', cobrancaId)
        .order('type');
    return data.map((json) => CobrancaItem.fromJson(json)).toList();
  }

  Future<List<CobrancaWithStudent>> getMonthBills(String monthYear) async {
    final data = await _client
        .from('cobrancas')
        .select('*, profiles:student_id(full_name)')
        .eq('month_year', monthYear)
        .order('total_amount', ascending: false);

    return data.map((json) {
      final profileData = json['profiles'] as Map<String, dynamic>?;
      return CobrancaWithStudent(
        cobranca: Cobranca.fromJson(json),
        studentName: profileData?['full_name'] as String? ?? '',
      );
    }).toList();
  }

  /// Admin confirma cobrança (muda de draft para pending)
  Future<void> confirmBill(String cobrancaId) async {
    await _client.from('cobrancas').update({
      'status': 'pending',
      'admin_confirmed': true,
    }).eq('id', cobrancaId);
  }

  /// Admin notifica aluna da cobrança
  Future<void> notifyBill(String cobrancaId) async {
    final bill = await _client
        .from('cobrancas')
        .select('student_id, total_amount, month_year')
        .eq('id', cobrancaId)
        .single();

    await _client.from('cobrancas').update({
      'status': 'notified',
      'notified_at': DateTime.now().toIso8601String(),
    }).eq('id', cobrancaId);

    await _client.from('notifications').insert({
      'user_id': bill['student_id'],
      'title': 'Cobrança disponível',
      'body':
          'Sua cobrança de ${bill['month_year']} no valor de R\$${(bill['total_amount'] as num).toStringAsFixed(2)} está pronta.',
      'type': 'billing',
      'data': {'cobranca_id': cobrancaId},
    });
  }

  /// Aluna registra pagamento
  Future<void> registerPayment(
    String cobrancaId,
    PaymentMethod method,
    String? reference,
  ) async {
    await _client.from('cobrancas').update({
      'status': 'paid',
      'payment_method': method.name,
      'payment_reference': reference,
      'paid_at': DateTime.now().toIso8601String(),
    }).eq('id', cobrancaId);
  }

  /// Totalizar cobranças do mês (chama edge function)
  Future<Map<String, dynamic>> totalizeBills(String monthYear) async {
    final response = await _client.functions.invoke(
      'totalizar-cobranca',
      body: {'month_year': monthYear},
    );
    return response.data as Map<String, dynamic>;
  }

  /// Resumo financeiro do mês (admin)
  Future<Map<String, double>> getMonthSummary(String monthYear) async {
    final data = await _client
        .from('cobrancas')
        .select('total_amount, status')
        .eq('month_year', monthYear);

    double total = 0;
    double paid = 0;
    double pending = 0;

    for (final bill in data) {
      final amount = (bill['total_amount'] as num).toDouble();
      total += amount;
      if (bill['status'] == 'paid') {
        paid += amount;
      } else {
        pending += amount;
      }
    }

    return {'total': total, 'paid': paid, 'pending': pending};
  }
}
