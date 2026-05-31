class AssetAccountModel {
  final String id;
  final String userId;
  final String accountType;
  final String accountName;
  final String institutionCode;
  final String accountNumber;
  final double cashBalance;
  final bool isPrimary;
  final bool isActive;
  final DateTime? createdAt;

  const AssetAccountModel({
    required this.id,
    required this.userId,
    required this.accountType,
    required this.accountName,
    required this.institutionCode,
    required this.accountNumber,
    required this.cashBalance,
    required this.isPrimary,
    required this.isActive,
    required this.createdAt,
  });

  String get typeLabel {
    switch (accountType) {
      case 'bank':
        return '입출금';
      case 'stock':
        return '주식';
      case 'coin':
        return '코인';
      case 'real_estate':
        return '부동산';
      default:
        return accountType;
    }
  }

  factory AssetAccountModel.fromMap(Map<String, dynamic> map) {
    return AssetAccountModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      accountType: map['account_type']?.toString() ?? '',
      accountName: map['account_name']?.toString() ?? '',
      institutionCode: map['institution_code']?.toString() ?? '',
      accountNumber: map['account_number']?.toString() ?? '',
      cashBalance: _toDouble(map['cash_balance']),
      isPrimary: map['is_primary'] == true,
      isActive: map['is_active'] == true,
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }
}