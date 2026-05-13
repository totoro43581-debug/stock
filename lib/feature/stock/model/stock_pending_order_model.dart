class StockPendingOrderModel {
  final String id;
  final String userId;
  final String stockCode;
  final String stockName;
  final String orderType;
  final double orderPrice;
  final int quantity;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StockPendingOrderModel({
    required this.id,
    required this.userId,
    required this.stockCode,
    required this.stockName,
    required this.orderType,
    required this.orderPrice,
    required this.quantity,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StockPendingOrderModel.fromMap(Map<String, dynamic> map) {
    return StockPendingOrderModel(
      id: (map['id'] ?? '').toString(),
      userId: (map['user_id'] ?? '').toString(),
      stockCode: (map['stock_code'] ?? '').toString(),
      stockName: (map['stock_name'] ?? '').toString(),
      orderType: (map['order_type'] ?? '').toString(),
      orderPrice: ((map['order_price'] ?? 0) as num).toDouble(),
      quantity: ((map['quantity'] ?? 0) as num).toInt(),
      status: (map['status'] ?? '').toString(),
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
      updatedAt: map['updated_at'] == null
          ? null
          : DateTime.tryParse(map['updated_at'].toString()),
    );
  }
}