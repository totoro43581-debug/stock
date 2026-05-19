class UserBankAccountModel {
  final String id;
  final String userId;
  final String productId;
  final String productNameSnapshot;
  final String productType;
  final double annualRateSnapshot;

  final double principalAmount;

  final double? installmentAmount;
  final int? totalInstallments;
  final int paidInstallments;

  final double expectedInterestAmount;
  final double expectedMaturityAmount;

  final DateTime startAt;
  final DateTime maturityAt;
  final DateTime? nextPaymentDueAt;

  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserBankAccountModel({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productNameSnapshot,
    required this.productType,
    required this.annualRateSnapshot,
    required this.principalAmount,
    required this.installmentAmount,
    required this.totalInstallments,
    required this.paidInstallments,
    required this.expectedInterestAmount,
    required this.expectedMaturityAmount,
    required this.startAt,
    required this.maturityAt,
    required this.nextPaymentDueAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isDeposit => productType == 'deposit';

  bool get isSavings => productType == 'savings';

  bool get isActive => status == 'active';

  bool get isMatured => status == 'matured';

  bool get isClosed => status == 'closed';

  int get remainingInstallments {
    if (!isSavings || totalInstallments == null) return 0;

    final remaining = totalInstallments! - paidInstallments;
    return remaining < 0 ? 0 : remaining;
  }

  double get savingsProgressRate {
    if (!isSavings || totalInstallments == null || totalInstallments == 0) {
      return 0;
    }

    return paidInstallments / totalInstallments!;
  }

  factory UserBankAccountModel.fromMap(Map<String, dynamic> map) {
    return UserBankAccountModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      productId: map['product_id']?.toString() ?? '',
      productNameSnapshot:
      map['product_name_snapshot']?.toString() ?? '',
      productType: map['product_type']?.toString() ?? '',
      annualRateSnapshot: _toDouble(map['annual_rate_snapshot']),
      principalAmount: _toDouble(map['principal_amount']),
      installmentAmount: map['installment_amount'] == null
          ? null
          : _toDouble(map['installment_amount']),
      totalInstallments: map['total_installments'] == null
          ? null
          : _toInt(map['total_installments']),
      paidInstallments: _toInt(map['paid_installments']),
      expectedInterestAmount:
      _toDouble(map['expected_interest_amount']),
      expectedMaturityAmount:
      _toDouble(map['expected_maturity_amount']),
      startAt: _toDateTime(map['start_at']),
      maturityAt: _toDateTime(map['maturity_at']),
      nextPaymentDueAt: map['next_payment_due_at'] == null
          ? null
          : _toDateTime(map['next_payment_due_at']),
      status: map['status']?.toString() ?? '',
      createdAt: _toDateTime(map['created_at']),
      updatedAt: _toDateTime(map['updated_at']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime _toDateTime(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return DateTime.tryParse(value.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }
}