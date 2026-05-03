class StockPriceModel {
  final String id;
  final String stockId;
  final double price;
  final DateTime recordedAt;

  StockPriceModel({
    required this.id,
    required this.stockId,
    required this.price,
    required this.recordedAt,
  });

  factory StockPriceModel.fromMap(Map<String, dynamic> map) {
    return StockPriceModel(
      id: map['id'].toString(),
      stockId: map['stock_id'].toString(),
      price: (map['price'] as num).toDouble(),
      recordedAt: DateTime.parse(map['created_at'].toString()),
    );
  }
}