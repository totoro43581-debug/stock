class WalletModel {
  final String id;
  final String userId;
  final int cashBalance;
  final int totalRewardReceived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const WalletModel({
    required this.id,
    required this.userId,
    required this.cashBalance,
    required this.totalRewardReceived,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      cashBalance: _readInt(
        map['cash_balance'] ?? map['balance'],
      ),
      totalRewardReceived: _readInt(map['total_reward_received']),
      createdAt: _readDateTime(map['created_at']),
      updatedAt: _readDateTime(map['updated_at']),
    );
  }

  static int _readInt(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    return DateTime.tryParse(value.toString());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'cash_balance': cashBalance,
      'total_reward_received': totalRewardReceived,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}