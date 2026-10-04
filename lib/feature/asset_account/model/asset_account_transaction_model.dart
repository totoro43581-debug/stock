class AssetAccountTransactionModel {
  final String id;
  final String userId;

  // bank / stock / coin / real_estate
  final String accountType;

  // 기존 데이터:
  // deposit / withdraw / transfer
  //
  // 신규 데이터:
  // in / out
  final String type;

  // point_to_asset
  // asset_transfer
  // stock_buy
  // stock_sell
  // coin_buy
  // coin_sell
  // ...
  final String reason;

  final double amount;
  final double balanceAfter;

  final String title;
  final String? memo;

  final DateTime createdAt;

  const AssetAccountTransactionModel({
    required this.id,
    required this.userId,
    required this.accountType,
    required this.type,
    required this.reason,
    required this.amount,
    required this.balanceAfter,
    required this.title,
    required this.memo,
    required this.createdAt,
  });

  // 신규/기존 데이터 모두 입금으로 판단
  bool get isDeposit {
    return type == 'in' || type == 'deposit';
  }

  // 신규/기존 데이터 모두 출금으로 판단
  bool get isWithdraw {
    return type == 'out' || type == 'withdraw';
  }

  String get accountTypeLabel {
    switch (accountType) {
      case 'bank':
        return '생활 현금';
      case 'stock':
        return '주식 투자';
      case 'coin':
        return '코인 투자';
      case 'real_estate':
        return '부동산 투자';
      default:
        return accountType;
    }
  }

  factory AssetAccountTransactionModel.fromMap(
      Map<String, dynamic> map,
      ) {
    return AssetAccountTransactionModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      accountType: map['account_type']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      reason: map['reason']?.toString() ?? '',
      amount: _toDouble(map['amount']),
      balanceAfter: _toDouble(map['balance_after']),
      title: map['title']?.toString() ?? '',
      memo: map['memo']?.toString(),
      createdAt:
      DateTime.tryParse(
        map['created_at']?.toString() ?? '',
      ) ??
          DateTime.now(),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    ) ??
        0;
  }
}