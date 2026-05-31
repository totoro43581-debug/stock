class AssetAccountTransactionModel {
  final String id;
  final String userId;

  /// deposit: 입금
  /// withdraw: 출금
  /// transfer: 이체
  final String type;

  /// point_to_asset: 포인트 → 자산계좌
  /// asset_to_deposit: 자산계좌 → 예금
  /// asset_to_savings: 자산계좌 → 적금
  /// asset_to_stock: 자산계좌 → 주식
  /// stock_to_asset: 주식 → 자산계좌
  final String reason;

  final double amount;
  final double balanceAfter;

  final String title;
  final String? memo;

  final DateTime createdAt;

  AssetAccountTransactionModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.reason,
    required this.amount,
    required this.balanceAfter,
    required this.title,
    this.memo,
    required this.createdAt,
  });

  factory AssetAccountTransactionModel.fromMap(Map<String, dynamic> map) {
    return AssetAccountTransactionModel(
      id: map['id'] ?? '',
      userId: map['user_id'] ?? '',
      type: map['type'] ?? '',
      reason: map['reason'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      balanceAfter: (map['balance_after'] ?? 0).toDouble(),
      title: map['title'] ?? '',
      memo: map['memo'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}