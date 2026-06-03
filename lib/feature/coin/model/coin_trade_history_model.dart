class CoinTradeHistoryModel {
  final String id;
  final String userId;
  final String coinCode;
  final String coinName;
  final String tradeType;
  final double tradePrice;
  final double quantity;
  final double totalAmount;
  final double fee;
  final DateTime? createdAt;

  const CoinTradeHistoryModel({
    required this.id,
    required this.userId,
    required this.coinCode,
    required this.coinName,
    required this.tradeType,
    required this.tradePrice,
    required this.quantity,
    required this.totalAmount,
    required this.fee,
    required this.createdAt,
  });

  factory CoinTradeHistoryModel.fromMap(Map<String, dynamic> map) {
    return CoinTradeHistoryModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      coinCode: map['coin_code']?.toString() ?? '',
      coinName: map['coin_name']?.toString() ?? '',
      tradeType: map['trade_type']?.toString() ?? '',
      tradePrice: _toDouble(map['trade_price']),
      quantity: _toDouble(map['quantity']),
      totalAmount: _toDouble(map['total_amount']),
      fee: _toDouble(map['fee']),
      createdAt: _toDateTime(map['created_at']),
    );
  }

  static double _toDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}