class BankProductModel {
  final String id;
  final String productCode;
  final String productName;

  // 수정4차: 상품이 속한 은행명 표시용
  final String bankName;

  final String productType;
  final String? description;
  final double annualRate;
  final int termDays;
  final double minAmount;
  final double? maxAmount;
  final int? installmentCount;
  final int? installmentIntervalDays;
  final bool isActive;

  const BankProductModel({
    required this.id,
    required this.productCode,
    required this.productName,
    required this.bankName,
    required this.productType,
    required this.description,
    required this.annualRate,
    required this.termDays,
    required this.minAmount,
    required this.maxAmount,
    required this.installmentCount,
    required this.installmentIntervalDays,
    required this.isActive,
  });

  bool get isDeposit => productType == 'deposit';

  bool get isSavings => productType == 'savings';

  factory BankProductModel.fromMap(Map<String, dynamic> map) {
    return BankProductModel(
      id: map['id']?.toString() ?? '',
      productCode: map['product_code']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      bankName: map['bank_name']?.toString() ?? '',
      productType: map['product_type']?.toString() ?? '',
      description: map['description']?.toString(),
      annualRate: _toDouble(map['annual_rate']),
      termDays: _toInt(map['term_days']),
      minAmount: _toDouble(map['min_amount']),
      maxAmount: map['max_amount'] == null
          ? null
          : _toDouble(map['max_amount']),
      installmentCount: map['installment_count'] == null
          ? null
          : _toInt(map['installment_count']),
      installmentIntervalDays: map['installment_interval_days'] == null
          ? null
          : _toInt(map['installment_interval_days']),
      isActive: map['is_active'] == true,
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
}