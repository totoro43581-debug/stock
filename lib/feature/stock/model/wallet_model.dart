class WalletModel {
  final String userId;
  final int cashBalance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WalletModel({
    required this.userId,
    required this.cashBalance,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      userId: map['user_id'] as String,
      cashBalance: (map['cash_balance'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'cash_balance': cashBalance,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  WalletModel copyWith({
    String? userId,
    int? cashBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WalletModel(
      userId: userId ?? this.userId,
      cashBalance: cashBalance ?? this.cashBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}