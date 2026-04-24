class StockHoldingModel {
  final String id;
  final String userId;
  final String stockCode;
  final String stockName;
  final int quantity;
  final double averagePrice;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StockHoldingModel({
    required this.id,
    required this.userId,
    required this.stockCode,
    required this.stockName,
    required this.quantity,
    required this.averagePrice,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockHoldingModel.fromMap(Map<String, dynamic> map) {
    return StockHoldingModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      stockCode: (map['stock_code'] ?? '').toString(),
      stockName: (map['stock_name'] ?? '').toString(),
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      averagePrice: ((map['average_price'] as num?) ?? 0).toDouble(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'].toString()),
    );
  }
}