class StockTradeHistoryModel {
  final String id;
  final String userId;
  final String stockCode;
  final String stockName;
  final String tradeType;
  final int quantity;
  final double price;
  final double totalAmount;
  final DateTime? createdAt;

  const StockTradeHistoryModel({
    required this.id,
    required this.userId,
    required this.stockCode,
    required this.stockName,
    required this.tradeType,
    required this.quantity,
    required this.price,
    required this.totalAmount,
    required this.createdAt,
  });

  factory StockTradeHistoryModel.fromMap(Map<String, dynamic> map) {
    return StockTradeHistoryModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      stockCode: (map['stock_code'] ?? '').toString(),
      stockName: (map['stock_name'] ?? '').toString(),
      tradeType: (map['trade_type'] ?? '').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      price: ((map['price'] as num?) ?? 0).toDouble(),
      totalAmount: ((map['total_amount'] as num?) ?? 0).toDouble(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }
}