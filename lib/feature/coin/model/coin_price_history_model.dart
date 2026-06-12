class CoinPriceHistoryModel {
  final String id;
  final String coinCode;
  final String coinName;
  final double price;
  final double changeRate;
  final double tradeVolume;
  final DateTime createdAt;

  const CoinPriceHistoryModel({
    required this.id,
    required this.coinCode,
    required this.coinName,
    required this.price,
    required this.changeRate,
    required this.tradeVolume,
    required this.createdAt,
  });

  factory CoinPriceHistoryModel.fromMap(Map<String, dynamic> map) {
    return CoinPriceHistoryModel(
      id: map['id']?.toString() ?? '',
      coinCode: map['coin_code']?.toString() ?? '',
      coinName: map['coin_name']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      changeRate: (map['change_rate'] as num?)?.toDouble() ?? 0,
      tradeVolume: (map['trade_volume'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}