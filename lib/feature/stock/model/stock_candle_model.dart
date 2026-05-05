class StockCandleModel {
  final int id;
  final int stockId;
  final double open;
  final double high;
  final double low;
  final double close;
  final int volume;
  final DateTime createdAt;

  StockCandleModel({
    required this.id,
    required this.stockId,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.createdAt,
  });

  factory StockCandleModel.fromMap(Map<String, dynamic> map) {
    return StockCandleModel(
      id: map['id'],
      stockId: map['stock_id'],
      open: (map['open_price'] as num).toDouble(),
      high: (map['high_price'] as num).toDouble(),
      low: (map['low_price'] as num).toDouble(),
      close: (map['close_price'] as num).toDouble(),
      volume: map['volume'] ?? 0,
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}