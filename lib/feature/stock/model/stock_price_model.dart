class StockPriceModel {
  final String id;
  final String stockId;
  final double price;
  final DateTime createdAt;

  StockPriceModel({
    required this.id,
    required this.stockId,
    required this.price,
    required this.createdAt,
  });

  factory StockPriceModel.fromMap(Map<String, dynamic> map) {
    return StockPriceModel(
      id: map['id'].toString(),
      stockId: map['stock_id'].toString(),
      price: ((map['price'] ?? 0) as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'].toString()),
    );
  }
}