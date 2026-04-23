enum CobrancaStatus { draft, pending, notified, paid, overdue, cancelled }

enum PaymentMethod { pix, card, external }

class Cobranca {
  final String id;
  final String studentId;
  final String monthYear;
  final double planAmount;
  final double clayAmount;
  final double firingAmount;
  final double totalAmount;
  final CobrancaStatus status;
  final PaymentMethod? paymentMethod;
  final String? paymentReference;
  final String? comprovanteUrl;
  final DateTime? comprovanteUploadedAt;
  final String? paymentNotes;
  final DateTime? paidAt;
  final DateTime? notifiedAt;
  final bool adminConfirmed;
  final DateTime createdAt;

  const Cobranca({
    required this.id,
    required this.studentId,
    required this.monthYear,
    required this.planAmount,
    required this.clayAmount,
    required this.firingAmount,
    required this.totalAmount,
    required this.status,
    this.paymentMethod,
    this.paymentReference,
    this.comprovanteUrl,
    this.comprovanteUploadedAt,
    this.paymentNotes,
    this.paidAt,
    this.notifiedAt,
    required this.adminConfirmed,
    required this.createdAt,
  });

  factory Cobranca.fromJson(Map<String, dynamic> json) {
    return Cobranca(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      monthYear: json['month_year'] as String,
      planAmount: (json['plan_amount'] as num).toDouble(),
      clayAmount: (json['clay_amount'] as num).toDouble(),
      firingAmount: (json['firing_amount'] as num).toDouble(),
      totalAmount: (json['total_amount'] as num).toDouble(),
      status: CobrancaStatus.values.byName(json['status'] as String),
      paymentMethod: json['payment_method'] != null
          ? PaymentMethod.values.byName(json['payment_method'] as String)
          : null,
      paymentReference: json['payment_reference'] as String?,
      comprovanteUrl: json['comprovante_url'] as String?,
      comprovanteUploadedAt: json['comprovante_uploaded_at'] != null
          ? DateTime.parse(json['comprovante_uploaded_at'] as String)
          : null,
      paymentNotes: json['payment_notes'] as String?,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      notifiedAt: json['notified_at'] != null
          ? DateTime.parse(json['notified_at'] as String)
          : null,
      adminConfirmed: json['admin_confirmed'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isPaid => status == CobrancaStatus.paid;
  bool get isPending =>
      status == CobrancaStatus.pending || status == CobrancaStatus.notified;
  bool get hasComprovante => comprovanteUrl != null;
}

class CobrancaItem {
  final String id;
  final String cobrancaId;
  final String type;
  final String description;
  final double? quantity;
  final double? unitPrice;
  final double total;
  final String? referenceId;

  const CobrancaItem({
    required this.id,
    required this.cobrancaId,
    required this.type,
    required this.description,
    this.quantity,
    this.unitPrice,
    required this.total,
    this.referenceId,
  });

  factory CobrancaItem.fromJson(Map<String, dynamic> json) {
    return CobrancaItem(
      id: json['id'] as String,
      cobrancaId: json['cobranca_id'] as String,
      type: json['type'] as String,
      description: json['description'] as String,
      quantity: (json['quantity'] as num?)?.toDouble(),
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
      total: (json['total'] as num).toDouble(),
      referenceId: json['reference_id'] as String?,
    );
  }
}
